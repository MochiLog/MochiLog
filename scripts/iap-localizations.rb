#!/usr/bin/env ruby
# Inspect or publish the Japanese App Store Connect metadata for existing tips.
# StoreKit configuration is only a local test fixture; live products need their
# own App Store Connect localizations.
require "base64"
require "json"
require "net/http"
require "openssl"
require "uri"
require "jwt"

APP_ID = "6756904240"
MODE = ARGV.fetch(0) { abort "Usage: ruby scripts/iap-localizations.rb inspect|apply" }
abort "Unknown mode" unless %w[inspect apply].include?(MODE)

class AppStoreConnectAPI
  def initialize
    key = Base64.strict_decode64(ENV.fetch("APP_STORE_CONNECT_API_KEY_CONTENT"))
    @private_key = OpenSSL::PKey::EC.new(key)
    @issuer = ENV.fetch("APP_STORE_CONNECT_API_ISSUER_ID")
    @key_id = ENV.fetch("APP_STORE_CONNECT_API_KEY_ID")
    @token = nil
    @expires_at = 0
  end

  def request(method, path, body = nil)
    now = Time.now.to_i
    if now >= @expires_at - 60
      @expires_at = now + 1_200
      @token = JWT.encode({ iss: @issuer, iat: now, exp: @expires_at,
        aud: "appstoreconnect-v1" }, @private_key, "ES256",
        { kid: @key_id, typ: "JWT" })
    end
    uri = URI("https://api.appstoreconnect.apple.com#{path}")
    attempts = 0
    loop do
      attempts += 1
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
        open_timeout: 20, read_timeout: 40) do |http|
        req = Net::HTTP.const_get(method.capitalize).new(uri)
        req["Authorization"] = "Bearer #{@token}"
        req["Content-Type"] = "application/json"
        req.body = JSON.generate(body) if body
        http.request(req)
      end
      if [429, 500, 502, 503, 504].include?(response.code.to_i) && attempts < 5
        sleep([attempts * 3, 15].min)
        next
      end
      parsed = JSON.parse(response.body.to_s.empty? ? "{}" : response.body)
      return parsed if (200..299).cover?(response.code.to_i)
      details = parsed.fetch("errors", []).map { |error|
        [error["code"], error["title"], error["detail"]].compact.join(": ")
      }.join("; ")
      raise "App Store Connect #{method} #{path} returned #{response.code}: #{details[0, 500]}"
    end
  end

  def all(path)
    rows = []
    while path
      result = request("GET", path)
      rows.concat(result.fetch("data"))
      path = result.dig("links", "next")
      path = URI(path).request_uri if path
    end
    rows
  end
end

fixture = JSON.parse(File.read(File.expand_path("../MochiLog/Resources/MochiLog.storekit", __dir__)))
wanted = fixture.fetch("products").to_h do |product|
  japanese = product.fetch("localizations").find { |item| item["locale"] == "ja" }
  raise "Missing Japanese fixture for #{product['productID']}" unless japanese
  [product.fetch("productID"), japanese]
end
api = AppStoreConnectAPI.new
products = api.all("/v1/apps/#{APP_ID}/inAppPurchasesV2?limit=50")
found = {}
products.each do |product|
  product_id = product.dig("attributes", "productId")
  next unless wanted.key?(product_id)
  found[product_id] = true
  localization = api.all("/v2/inAppPurchases/#{product.fetch('id')}/inAppPurchaseLocalizations?limit=200")
    .find { |item| item.dig("attributes", "locale") == "ja" }
  japanese = wanted.fetch(product_id)
  current_name = localization&.dig("attributes", "name")
  current_description = localization&.dig("attributes", "description")
  desired_name = japanese.fetch("displayName")
  desired_description = japanese.fetch("description")
  puts "#{product_id}: Japanese #{localization ? 'present' : 'missing'}" \
       " (name=#{current_name.inspect}, description=#{current_description.inspect})"
  next if MODE == "inspect" ||
    (current_name == desired_name && current_description == desired_description)

  if localization
    api.request("PATCH", "/v1/inAppPurchaseLocalizations/#{localization.fetch('id')}",
      data: { type: "inAppPurchaseLocalizations", id: localization.fetch("id"),
        attributes: { name: desired_name, description: desired_description } })
  else
    api.request("POST", "/v1/inAppPurchaseLocalizations",
      data: { type: "inAppPurchaseLocalizations",
        attributes: { locale: "ja", name: desired_name,
          description: desired_description },
        relationships: { inAppPurchaseV2: {
          data: { type: "inAppPurchases", id: product.fetch("id") } } } })
  end
  verified = api.all("/v2/inAppPurchases/#{product.fetch('id')}/inAppPurchaseLocalizations?limit=200")
    .find { |item| item.dig("attributes", "locale") == "ja" }
  raise "Japanese metadata did not persist for #{product_id}" unless
    verified&.dig("attributes", "name") == desired_name &&
    verified&.dig("attributes", "description") == desired_description
  puts "#{product_id}: Japanese metadata verified"
end
raise "Missing App Store Connect products: #{(wanted.keys - found.keys).join(', ')}" unless
  wanted.keys.all? { |id| found[id] }
