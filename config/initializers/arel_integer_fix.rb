# Fix for Arel 3.0.3 "Cannot visit Integer" error
# This occurs when integer values are passed directly to Arel queries
# in Ruby 2.6+ where Fixnum is deprecated and unified into Integer

require 'arel'
require 'arel/visitors/to_sql'

module Arel
  module Visitors
    class ToSql
      # Patch to handle Integer values that Arel 3.0.3 can't visit
      alias_method :original_visit, :visit
      
      def visit(object, *args)
        if object.is_a?(Integer)
          object.to_s
        else
          original_visit(object, *args)
        end
      end
    end
  end
end

Rails.logger.info "Arel Integer fix loaded" if defined?(Rails.logger) && Rails.logger