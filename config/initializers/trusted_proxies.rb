# Trust all proxies for Azure App Service
# This fixes: ActionDispatch::RemoteIp::IpSpoofAttackError

# For Rails 3.2, we need to monkey-patch the RemoteIp middleware
module ActionDispatch
  class RemoteIp
    class GetIp
      def calculate_ip
        # Just return the forwarded IP without spoofing check
        forwarded_ips = ips_from('HTTP_X_FORWARDED_FOR')
        return forwarded_ips.first if forwarded_ips.any?
        
        client_ip = ips_from('HTTP_CLIENT_IP')
        return client_ip.first if client_ip.any?
        
        remote_addr = ips_from('REMOTE_ADDR')
        remote_addr.first
      end

      private

      def ips_from(header)
        return [] unless @env[header]
        
        # Handle IP:port format from Azure
        @env[header].split(',').map { |ip| 
          ip.strip.split(':').first 
        }.reject { |ip| ip.blank? }
      end
    end
  end
end