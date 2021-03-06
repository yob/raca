require 'yaml'
require 'json'

module Raca

  # This is your entrypoint to the rackspace API. Start by creating a
  # Raca::Account object and then use the instance method to access each of
  # the supported rackspace APIs.
  #
  class Account
    IDENTITY_URL = "https://identity.api.rackspacecloud.com/v2.0/"

    def initialize(username, key, cache = nil)
      @username, @key, @cache = username, key, cache
      @cache ||= if defined?(Rails)
        Rails.cache
      else
        {}
      end
    end

    # Return the temporary token that should be used when making further API
    # requests.
    #
    #     account = Raca::Account.new("username", "secret")
    #     puts account.auth_token
    #
    def auth_token
      extract_value(identity_data, "access", "token", "id")
    end

    # Return the public API URL for a particular rackspace service.
    #
    # Use Account#service_names to see a list of valid service_name's for this.
    #
    # Check the project README for an updated list of the available regions.
    #
    #     account = Raca::Account.new("username", "secret")
    #     puts account.public_endpoint("cloudServers", :syd)
    #
    # Some service APIs are not regioned. In those cases, the region code can be
    # left off:
    #
    #     account = Raca::Account.new("username", "secret")
    #     puts account.public_endpoint("cloudDNS")
    #
    def public_endpoint(service_name, region = nil)
      return IDENTITY_URL if service_name == "identity"

      endpoints = service_endpoints(service_name)
      if endpoints.size > 1 && region
        region = region.to_s.upcase
        endpoints = endpoints.select { |e| e["region"] == region } || {}
      elsif endpoints.size > 1 && region.nil?
        raise ArgumentError, "The requested service exists in multiple regions, please specify a region code"
      end

      if endpoints.size == 0
        raise ArgumentError, "No matching services found"
      else
        endpoints.first["publicURL"]
      end
    end

    # Return the names of the available services. As rackspace add new services and
    # APIs they should appear here.
    #
    # Any name returned from here can be passe to #public_endpoint to get the API
    # endpoint for that service
    #
    #     account = Raca::Account.new("username", "secret")
    #     puts account.service_names
    #
    def service_names
      catalog = extract_value(identity_data, "access", "serviceCatalog") || {}
      catalog.map { |service|
        service["name"]
      }
    end

    # Return a Raca::Containers object for a region. Use this to interact with the
    # cloud files service.
    #
    #     account = Raca::Account.new("username", "secret")
    #     puts account.containers(:ord)
    #
    def containers(region)
      Raca::Containers.new(self, region)
    end

    # Return a Raca::Servers object for a region. Use this to interact with the
    # next gen cloud servers service.
    #
    #     account = Raca::Account.new("username", "secret")
    #     puts account.servers(:ord)
    #
    def servers(region)
      Raca::Servers.new(self, region)
    end

    # Return a Raca::Users object. Use this to query and manage the users associated
    # with the current account.
    #
    #     account = Raca::Account.new("username", "secret")
    #     puts account.users
    #
    def users
      Raca::Users.new(self)
    end

    # Raca classes use this method to occasionally re-authenticate with the rackspace
    # servers. You can probably ignore it.
    #
    def refresh_cache
      # Raca::HttpClient depends on Raca::Account, so we intentionally don't use it here
      # to avoid a circular dependency
      Net::HTTP.new(identity_host, 443).tap {|http|
        http.use_ssl = true
      }.start {|http|
        payload = {
          auth: {
            'RAX-KSKEY:apiKeyCredentials' => {
              username: @username,
              apiKey: @key
            }
          }
        }
        response = http.post(
          tokens_path,
          JSON.dump(payload),
          {'Content-Type' => 'application/json'},
        )
        if response.is_a?(Net::HTTPSuccess)
          cache_write(cache_key, JSON.load(response.body))
        else
          raise_on_error(response)
        end
      }
    end

    # Return a Raca::HttpClient suitable for making requests to hostname.
    #
    def http_client(hostname)
      Raca::HttpClient.new(self, hostname)
    end

    def inspect
      "#<Raca::Account:#{__id__} username=#{@username}>"
    end

    private

    def identity_host
      URI.parse(IDENTITY_URL).host
    end

    def identity_path
      URI.parse(IDENTITY_URL).path
    end

    def tokens_path
      File.join(identity_path, "tokens")
    end

    def raise_on_error(response)
      error_klass = case response.code.to_i
      when 400 then BadRequestError
      when 401 then UnauthorizedError
      when 404 then NotFoundError
      when 500 then ServerError
      else
        HTTPError
      end
      raise error_klass, "Rackspace returned HTTP status #{response.code}"
    end

    # This method is opaque, but it was the best I could come up with using just
    # the standard library. Sorry.
    #
    # Use this to safely extract values from nested hashes:
    #
    #     data = {a: {b: {c: 1}}}
    #     extract_value(data, :a, :b, :c)
    #     => 1
    #
    #     extract_value(data, :a, :b, :d)
    #     => nil
    #
    #     extract_value(data, :d)
    #     => nil
    #
    def extract_value(data, *keys)
      if keys.empty?
        data
      elsif data.respond_to?(:[]) && data[keys.first]
        extract_value(data[keys.first], *keys.slice(1,100))
      else
        nil
      end
    end

    # An array of all the endpoints for a particular service (like cloud files,
    # cloud servers, dns, etc)
    #
    def service_endpoints(service_name)
      catalog = extract_value(identity_data, "access", "serviceCatalog") || {}
      service = catalog.detect { |s| s["name"] == service_name } || {}
      service["endpoints"] || []
    end

    def cache_read(key)
      if @cache.respond_to?(:read) # rails cache
        @cache.read(key)
      else
        @cache[key]
      end
    end

    def cache_write(key, value)
      if @cache.respond_to?(:write) # rails cache
        @cache.write(key, value)
      else
        @cache[key] = value
      end
    end

    def identity_data
      refresh_cache unless cache_read(cache_key)

      cache_read(cache_key) || {}
    end

    def cache_key
      "raca-#{@username}"
    end

  end
end
