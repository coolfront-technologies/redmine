# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'uri'
require 'cgi'

class Unauthorized < Exception; end

class ApplicationController < ActionController::Base
  include Redmine::I18n
  include Redmine::Pagination
  include RoutesHelper
  helper :routes

  class_attribute :accept_api_auth_actions
  class_attribute :accept_rss_auth_actions
  class_attribute :model_object

  layout 'base'

  protect_from_forgery
  def handle_unverified_request
    super
    cookies.delete(autologin_cookie_name)
    cookies.delete(:_redmine_user_id)
  end

  before_filter :restore_user_from_simple_cookie
  before_filter :session_expiration, :user_setup, :check_if_login_required, :set_localization

  rescue_from StandardError, :with => :render_error
  rescue_from ActionController::InvalidAuthenticityToken, :with => :invalid_authenticity_token
  rescue_from ::Unauthorized, :with => :deny_access
  rescue_from ::ActionView::MissingTemplate, :with => :missing_template

  include Redmine::Search::Controller
  include Redmine::MenuManager::MenuController
  helper Redmine::MenuManager::MenuHelper

  # Simple cookie authentication - bypasses Rails session issues
  def restore_user_from_simple_cookie
    # DEBUG: Log all cookies
    logger.info "=== DEBUG COOKIES ==="
    logger.info "All cookies: #{cookies.to_h.keys.inspect}"
    logger.info "_redmine_user_id cookie: #{cookies[:_redmine_user_id].inspect}"
    logger.info "Raw HTTP_COOKIE: #{request.env['HTTP_COOKIE'].inspect}"
    logger.info "===================="
    
    if cookies[:_redmine_user_id].present? && (User.current.nil? || User.current.anonymous?)
      begin
        user_id = cookies[:_redmine_user_id].to_i
        logger.info "Found user_id in cookie: #{user_id}"
        user = User.find_by_id(user_id)
        if user && user.active?
          logger.info "Restoring user from simple cookie: #{user.login}"
          User.current = user
          session[:user_id] = user.id rescue nil
          session[:ctime] = Time.now.utc.to_i rescue nil
          session[:atime] = Time.now.utc.to_i rescue nil
        else
          logger.warn "User not found or inactive for id: #{user_id}"
          cookies.delete(:_redmine_user_id)
        end
      rescue => e
        logger.error "Simple cookie auth error: #{e.message}"
        cookies.delete(:_redmine_user_id)
      end
    else
      logger.info "No _redmine_user_id cookie found"
    end
  end

  def set_simple_auth_cookie(user)
    logger.info "=== SETTING SIMPLE AUTH COOKIE ==="
    logger.info "User ID: #{user.id}"
    cookies[:_redmine_user_id] = {
      :value => user.id.to_s,
      :expires => 1.day.from_now,
      :path => '/',
      :httponly => true
    }
    logger.info "Cookie set with value: #{user.id}"
    logger.info "=================================="
  end

  def clear_simple_auth_cookie
    cookies.delete(:_redmine_user_id, :path => '/')
  end

  def session_expiration
    if session[:user_id]
      if session_expired? && !try_to_autologin
        reset_session
        clear_simple_auth_cookie
        flash[:error] = l(:error_session_expired)
        redirect_to signin_url
      else
        session[:atime] = Time.now.utc.to_i
      end
    end
  end

  def session_expired?
    if Setting.session_lifetime?
      unless session[:ctime] && (Time.now.utc.to_i - session[:ctime].to_i <= Setting.session_lifetime.to_i * 60)
        return true
      end
    end
    if Setting.session_timeout?
      unless session[:atime] && (Time.now.utc.to_i - session[:atime].to_i <= Setting.session_timeout.to_i * 60)
        return true
      end
    end
    false
  end

  def start_user_session(user)
    session[:user_id] = user.id
    session[:ctime] = Time.now.utc.to_i
    session[:atime] = Time.now.utc.to_i
    set_simple_auth_cookie(user)
  end

  def user_setup
    Setting.check_cache
    User.current = find_current_user
    logger.info("  Current user: " + (User.current.logged? ? "#{User.current.login} (id=#{User.current.id})" : "anonymous")) if logger
  end

  def find_current_user
    user = nil
    unless api_request?
      # First check simple cookie (most reliable for Azure)
      if cookies[:_redmine_user_id].present?
        user = User.active.find_by_id(cookies[:_redmine_user_id].to_i)
        logger.info "Found user from simple cookie: #{user.login}" if user
      end
      # Then check session
      if user.nil? && session[:user_id]
        user = (User.active.find(session[:user_id]) rescue nil)
        logger.info "Found user from session: #{user.login}" if user
      end
      # Then try autologin
      if user.nil?
        user = try_to_autologin
      end
      # RSS key auth
      if user.nil? && params[:format] == 'atom' && params[:key] && request.get? && accept_rss_auth?
        user = User.find_by_rss_key(params[:key])
      end
    end
    if user.nil? && Setting.rest_api_enabled? && accept_api_auth?
      if (key = api_key_from_request)
        user = User.find_by_api_key(key)
      else
        authenticate_with_http_basic do |username, password|
          user = User.try_to_login(username, password) || User.find_by_api_key(username)
        end
      end
    end
    user
  end

  def autologin_cookie_name
    Redmine::Configuration['autologin_cookie_name'].presence || 'autologin'
  end

  def try_to_autologin
    if cookies[autologin_cookie_name] && Setting.autologin?
      user = User.try_to_autologin(cookies[autologin_cookie_name])
      if user
        reset_session
        start_user_session(user)
      end
      user
    end
  end

  def logged_user=(user)
    reset_session
    if user && user.is_a?(User)
      User.current = user
      start_user_session(user)
      set_simple_auth_cookie(user)
    else
      User.current = User.anonymous
      clear_simple_auth_cookie
    end
  end

  def logout_user
    if User.current.logged?
      cookies.delete(autologin_cookie_name)
      clear_simple_auth_cookie
      Token.delete_all(["user_id = ? AND action = ?", User.current.id, 'autologin'])
      self.logged_user = nil
    end
  end

  def check_if_login_required
    return true if User.current.logged?
    require_login if Setting.login_required?
  end

  def set_localization
    lang = nil
    if User.current.logged?
      lang = find_language(User.current.language)
    end
    if lang.nil? && request.env['HTTP_ACCEPT_LANGUAGE']
      accept_lang = parse_qvalues(request.env['HTTP_ACCEPT_LANGUAGE']).first
      if !accept_lang.blank?
        accept_lang = accept_lang.downcase
        lang = find_language(accept_lang) || find_language(accept_lang.split('-').first)
      end
    end
    lang ||= Setting.default_language
    set_language_if_valid(lang)
  end

  def require_login
    if !User.current.logged?
      if request.get?
        url = url_for(params)
      else
        url = url_for(:controller => params[:controller], :action => params[:action], :id => params[:id], :project_id => params[:project_id])
      end
      respond_to do |format|
        format.html { redirect_to :controller => "account", :action => "login", :back_url => url }
        format.atom { redirect_to :controller => "account", :action => "login", :back_url => url }
        format.xml  { head :unauthorized, 'WWW-Authenticate' => 'Basic realm="Redmine API"' }
        format.js   { head :unauthorized, 'WWW-Authenticate' => 'Basic realm="Redmine API"' }
        format.json { head :unauthorized, 'WWW-Authenticate' => 'Basic realm="Redmine API"' }
      end
      return false
    end
    true
  end

  def require_admin
    return unless require_login
    if !User.current.admin?
      render_403
      return false
    end
    true
  end

  def deny_access
    User.current.logged? ? render_403 : require_login
  end

  def authorize(ctrl = params[:controller], action = params[:action], global = false)
    allowed = User.current.allowed_to?({:controller => ctrl, :action => action}, @project || @projects, :global => global)
    if allowed
      true
    else
      if @project && @project.archived?
        render_403 :message => :notice_not_authorized_archived_project
      else
        deny_access
      end
    end
  end

  def authorize_global(ctrl = params[:controller], action = params[:action], global = true)
    authorize(ctrl, action, global)
  end

  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project_by_project_id
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_optional_project
    @project = Project.find(params[:project_id]) unless params[:project_id].blank?
    allowed = User.current.allowed_to?({:controller => params[:controller], :action => params[:action]}, @project, :global => true)
    allowed ? true : deny_access
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project_from_association
    render_404 unless @object.present?
    @project = @object.project
  end

  def find_model_object
    model = self.class.model_object
    if model
      @object = model.find(params[:id])
      self.instance_variable_set('@' + controller_name.singularize, @object) if @object
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def self.model_object(model)
    self.model_object = model
  end

  def find_issue
    @issue = Issue.find(params[:id])
    raise Unauthorized unless @issue.visible?
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_issues
    @issues = Issue.find_all_by_id(params[:id] || params[:ids])
    raise ActiveRecord::RecordNotFound if @issues.empty?
    raise Unauthorized unless @issues.all?(&:visible?)
    @projects = @issues.collect(&:project).compact.uniq
    @project = @projects.first if @projects.size == 1
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_attachments
    if (attachments = params[:attachments]).present?
      att = attachments.values.collect do |attachment|
        Attachment.find_by_token( attachment[:token] ) if attachment[:token].present?
      end
      att.compact!
    end
    @attachments = att || []
  end

  def check_project_privacy
    if @project && !@project.archived?
      if @project.visible?
        true
      else
        deny_access
      end
    else
      @project = nil
      render_404
      false
    end
  end

  def back_url
    url = params[:back_url]
    if url.nil? && referer = request.env['HTTP_REFERER']
      url = CGI.unescape(referer.to_s)
    end
    url
  end

  def redirect_back_or_default(default)
    back_url = params[:back_url].to_s
    if back_url.present?
      begin
        uri = URI.parse(back_url)
        if (uri.relative? || (uri.host == request.host)) && !uri.path.match(%r{/(login|account/register)})
          redirect_to(back_url)
          return
        end
      rescue URI::InvalidURIError
        logger.warn("Could not redirect to invalid URL #{back_url}")
      end
    end
    redirect_to default
    false
  end

  def redirect_to_referer_or(*args, &block)
    redirect_to :back
  rescue ::ActionController::RedirectBackError
    if args.any?
      redirect_to *args
    elsif block_given?
      block.call
    else
      raise "#redirect_to_referer_or takes arguments or a block"
    end
  end

  def render_403(options={})
    @project = nil
    render_error({:message => :notice_not_authorized, :status => 403}.merge(options))
    return false
  end

  def render_404(options={})
    render_error({:message => :notice_file_not_found, :status => 404}.merge(options))
    return false
  end

  def render_error(arg)
    arg = {:message => arg} unless arg.is_a?(Hash)
    @message = arg[:message]
    @message = l(@message) if @message.is_a?(Symbol)
    @status = arg[:status] || 500

    respond_to do |format|
      format.html {
        render :template => 'common/error', :layout => use_layout, :status => @status
      }
      format.any { head @status }
    end
  end

  def missing_template
    logger.warn "Missing template, responding with 404"
    @project = nil
    render_404
  end

  def require_admin_or_api_request
    return true if api_request?
    if User.current.admin?
      true
    elsif User.current.logged?
      render_error(:status => 406)
    else
      deny_access
    end
  end

  def use_layout
    request.xhr? ? false : 'base'
  end

  def invalid_authenticity_token
    if api_request?
      logger.error "Form authenticity token is missing or is invalid."
    end
    render_error "Invalid form authenticity token."
  end

  def render_feed(items, options={})
    @items = items || []
    @items.sort! {|x,y| y.event_datetime <=> x.event_datetime }
    @items = @items.slice(0, Setting.feeds_limit.to_i)
    @title = options[:title] || Setting.app_title
    render :template => "common/feed", :formats => [:atom], :layout => false,
           :content_type => 'application/atom+xml'
  end

  def self.accept_rss_auth(*actions)
    if actions.any?
      self.accept_rss_auth_actions = actions
    else
      self.accept_rss_auth_actions || []
    end
  end

  def accept_rss_auth?(action=action_name)
    self.class.accept_rss_auth.include?(action.to_sym)
  end

  def self.accept_api_auth(*actions)
    if actions.any?
      self.accept_api_auth_actions = actions
    else
      self.accept_api_auth_actions || []
    end
  end

  def accept_api_auth?(action=action_name)
    self.class.accept_api_auth.include?(action.to_sym)
  end

  def per_page_option
    per_page = nil
    if params[:per_page] && Setting.per_page_options_array.include?(params[:per_page].to_s.to_i)
      per_page = params[:per_page].to_s.to_i
      session[:per_page] = per_page
    elsif session[:per_page]
      per_page = session[:per_page]
    else
      per_page = Setting.per_page_options_array.first || 25
    end
    per_page
  end

  def api_offset_and_limit(options=params)
    if options[:offset].present?
      offset = options[:offset].to_i
      if offset < 0
        offset = 0
      end
    end
    limit = options[:limit].to_i
    if limit < 1
      limit = 25
    elsif limit > 100
      limit = 100
    end
    if offset.nil? && options[:page].present?
      offset = (options[:page].to_i - 1) * limit
      offset = 0 if offset < 0
    end
    offset ||= 0
    [offset, limit]
  end

  def parse_qvalues(value)
    tmp = []
    if value
      parts = value.split(/,\s*/)
      parts.each {|part|
        if m = %r{^([^\s,]+?)(?:;\s*q=(\d+(?:\.\d+)?))?$}.match(part)
          val = m[1]
          q = (m[2] or 1).to_f
          tmp.push([val, q])
        end
      }
      tmp = tmp.sort_by{|val, q| -q}
      tmp.collect!{|val, q| val}
    end
    return tmp
  rescue
    nil
  end

  def filename_for_content_disposition(name)
    request.env['HTTP_USER_AGENT'] =~ %r{MSIE} ? ERB::Util.url_encode(name) : name
  end

  def api_request?
    %w(xml json).include? params[:format]
  end

  def api_key_from_request
    if params[:key].present?
      params[:key].to_s
    elsif request.headers["X-Redmine-API-Key"].present?
      request.headers["X-Redmine-API-Key"].to_s
    end
  end

  def api_switch_user_from_request
    request.headers["X-Redmine-Switch-User"].to_s.presence
  end

  def render_attachment_warning_if_needed(obj)
    flash[:warning] = l(:warning_attachments_not_saved, obj.unsaved_attachments.size) if obj.unsaved_attachments.present?
  end

  def set_flash_from_bulk_issue_save(issues, unsaved_issue_ids)
    if unsaved_issue_ids.empty?
      flash[:notice] = l(:notice_successful_update) unless issues.empty?
    else
      flash[:error] = l(:notice_failed_to_save_issues,
                        :count => unsaved_issue_ids.size,
                        :total => issues.size,
                        :ids => '#' + unsaved_issue_ids.join(', #'))
    end
  end

  def query_statement_invalid(exception)
    logger.error "Query::StatementInvalid: #{exception.message}" if logger
    session.delete(:query)
    sort_clear if respond_to?(:sort_clear)
    render_error "An error occurred while executing the query and has been logged."
  end

  def render_api_ok
    render_api_head :ok
  end

  def render_api_head(status)
    render :text => '', :status => status, :layout => nil
  end

  def render_validation_errors(objects)
    if objects.is_a?(Array)
      @error_messages = objects.map {|object| object.errors.full_messages}.flatten
    else
      @error_messages = objects.errors.full_messages
    end
    render :template => 'common/error_messages.api', :status => :unprocessable_entity, :layout => nil
  end

  def _include_layout?(*args)
    api_request? ? false : super
  end
end