# Force Rails 3.2 to detect HTTPS from Azure proxy headers
module ActionController
    class Request
      def ssl?
        @env["HTTP_X_FORWARDED_PROTO"] == "https" ||
        @env["HTTP_X_ARR_SSL"].present? ||
        @env["HTTPS"] == "on" ||
        @env["rack.url_scheme"] == "https"
      end
    end
  end