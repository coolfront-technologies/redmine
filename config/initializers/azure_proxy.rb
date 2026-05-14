# Make Azure App Service work like Heroku

# 1. Trust all proxies (like Heroku does)
Rails.application.config.action_dispatch.trusted_proxies = %r{.*} rescue nil

# 2. Fix IP:PORT format from Azure (Heroku doesn't send port)
module ActionDispatch
  class RemoteIp
    class GetIp
      def calculate_ip
        # Extract IP without port (Azure sends IP:PORT)
        ['HTTP_X_FORWARDED_FOR', 'HTTP_CLIENT_IP', 'HTTP_X_REAL_IP', 'REMOTE_ADDR'].each do |header|
          next unless @env[header]
          # Split by comma (multiple proxies), take first, remove port
          ip = @env[header].to_s.split(',').first.to_s.split(':').first.to_s.strip
          return ip unless ip.empty?
        end
        '127.0.0.1'
      end
    end
  end
end

# 3. Force HTTPS detection from proxy headers (like Heroku)
if defined?(Rack::Request)
  class Rack::Request
    def ssl?
      @env['HTTP_X_FORWARDED_PROTO'] == 'https' ||
      @env['HTTP_X_ARR_SSL'].present? ||
      @env['HTTPS'] == 'on' ||
      scheme == 'https'
    end
  end
end