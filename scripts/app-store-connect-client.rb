# frozen_string_literal: true
require "base64"
require "json"
require "net/http"
require "openssl"
require "uri"
require "jwt"

class AppStoreConnect
  def initialize
    @key = OpenSSL::PKey::EC.new(Base64.strict_decode64(ENV.fetch("APP_STORE_CONNECT_API_KEY_CONTENT")))
    @issuer = ENV.fetch("APP_STORE_CONNECT_API_ISSUER_ID")
    @key_id = ENV.fetch("APP_STORE_CONNECT_API_KEY_ID")
    @expires_at = 0
  end

  def token
    now = Time.now.to_i
    return @token if now < @expires_at - 60
    @expires_at = now + 1_200
    @token = JWT.encode(
      { iss: @issuer, iat: now, exp: @expires_at, aud: "appstoreconnect-v1" },
      @key, "ES256", { kid: @key_id, typ: "JWT" }
    )
  end

  def get(path, params = {}) = request("GET", path, params)
  def post(path, body) = request("POST", path, {}, body)
  def patch(path, body) = request("PATCH", path, {}, body)

  def request(method, path, params = {}, body = nil)
    uri = URI("https://api.appstoreconnect.apple.com/v1#{path}")
    uri.query = URI.encode_www_form(params) unless params.empty?
    attempts = 0
    loop do
      attempts += 1
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
        open_timeout: 20, read_timeout: 40) do |http|
        request = Net::HTTP.const_get(method.capitalize).new(uri)
        request["Authorization"] = "Bearer #{token}"
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(body) if body
        http.request(request)
      end
      if [429, 500, 502, 503, 504].include?(response.code.to_i) && attempts < 5
        sleep([attempts * 3, 15].min)
        next
      end
      return nil if response.code.to_i == 204
      parsed = JSON.parse(response.body.to_s.empty? ? "{}" : response.body)
      return parsed if (200..299).cover?(response.code.to_i)
      details = parsed.fetch("errors", []).map { |error|
        [error["code"], error["title"], error["detail"]].compact.join(": ")
      }.join("; ")
      raise "App Store Connect #{method} #{path} returned #{response.code}: #{details[0, 500]}"
    end
  end
end
