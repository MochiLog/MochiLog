#!/usr/bin/env ruby
# Publish the two localized TestFlight build notes and add an uploaded build
# to MochiLog's existing tester groups. API credentials come from Actions.
require "base64"
require "json"
require "net/http"
require "openssl"
require "uri"
require "jwt"

APP_ID = "6756904240"
BUNDLE_ID = "net.ryuya-dev.MochiLog"
BASE_URL = "https://api.appstoreconnect.apple.com/v1"

class AppStoreConnect
  def initialize
    key = OpenSSL::PKey::EC.new(Base64.strict_decode64(ENV.fetch("APP_STORE_CONNECT_API_KEY_CONTENT")))
    now = Time.now.to_i
    @token = JWT.encode(
      { iss: ENV.fetch("APP_STORE_CONNECT_API_ISSUER_ID"), iat: now, exp: now + 1_200,
        aud: "appstoreconnect-v1" }, key, "ES256",
      { kid: ENV.fetch("APP_STORE_CONNECT_API_KEY_ID"), typ: "JWT" }
    )
  end

  def get(path, params = {}) = request("GET", path, params)
  def post(path, body) = request("POST", path, {}, body)
  def patch(path, body) = request("PATCH", path, {}, body)

  def request(method, path, params = {}, body = nil)
    uri = URI("#{BASE_URL}#{path}")
    uri.query = URI.encode_www_form(params) unless params.empty?
    attempts = 0
    loop do
      attempts += 1
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
        open_timeout: 20, read_timeout: 40) do |http|
        request = Net::HTTP.const_get(method.capitalize).new(uri)
        request["Authorization"] = "Bearer #{@token}"
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

def build_for(api, marketing_version, build_number, wait:)
  deadline = Time.now + (wait ? 1_800 : 0)
  loop do
    result = api.get("/builds", "filter[app]" => APP_ID,
      "filter[version]" => build_number, "include" => "preReleaseVersion", "limit" => "20")
    result.fetch("data", []).each do |build|
      prerelease = result.fetch("included", []).find { |item|
        item["type"] == "preReleaseVersions" &&
          item["id"] == build.dig("relationships", "preReleaseVersion", "data", "id")
      }
      next unless prerelease&.dig("attributes", "version") == marketing_version
      state = build.dig("attributes", "processingState")
      return build if state == "VALID"
      raise "Build #{marketing_version} (#{build_number}) processing failed: #{state}" if %w[FAILED INVALID].include?(state)
      puts "Build #{marketing_version} (#{build_number}) is #{state}; waiting for processing."
      break
    end
    raise "Build #{marketing_version} (#{build_number}) is not processed yet" if Time.now >= deadline
    sleep 30
  end
end

def publish_localizations(api, build_id)
  existing = api.get("/builds/#{build_id}/betaBuildLocalizations", "limit" => "200")
    .fetch("data", []).to_h { |item| [item.dig("attributes", "locale"), item] }
  { "ja" => "ja.txt", "en-US" => "en-US.txt" }.each do |locale, filename|
    text = File.read(File.expand_path("../fastlane/testflight/#{filename}", __dir__), encoding: "UTF-8").strip
    raise "#{locale} note exceeds 4,000 characters" if text.length > 4_000
    if (item = existing[locale])
      api.patch("/betaBuildLocalizations/#{item.fetch('id')}",
        data: { type: "betaBuildLocalizations", id: item.fetch("id"), attributes: { whatsNew: text } })
    else
      api.post("/betaBuildLocalizations", data: { type: "betaBuildLocalizations",
        attributes: { locale: locale, whatsNew: text },
        relationships: { build: { data: { type: "builds", id: build_id } } } })
    end
    puts "Published #{locale} TestFlight note (#{text.length} characters)."
  end
  saved = api.get("/builds/#{build_id}/betaBuildLocalizations", "limit" => "200")
    .fetch("data", []).map { |item| item.dig("attributes", "locale") }
  raise "Missing localized TestFlight notes: #{saved.inspect}" unless %w[ja en-US].all? { |locale| saved.include?(locale) }
end

def assign_existing_groups(api, build_id)
  groups = api.get("/betaGroups", "filter[app]" => APP_ID, "limit" => "200").fetch("data", [])
  raise "No existing TestFlight groups found; refusing to create or invite testers" if groups.empty?
  groups.each do |group|
    group_id = group.fetch("id")
    name = group.dig("attributes", "name")
    kind = group.dig("attributes", "isInternalGroup") ? "internal" : "external"
    linked = api.get("/betaGroups/#{group_id}/relationships/builds", "limit" => "200")
      .fetch("data", []).any? { |item| item["id"] == build_id }
    unless linked
      api.post("/betaGroups/#{group_id}/relationships/builds",
        data: [{ type: "builds", id: build_id }])
    end
    puts "#{kind} group #{name}: build #{linked ? 'already assigned' : 'assigned'}."
  end
  groups.count { |group| group.dig("attributes", "isInternalGroup") == false }
end

mode, marketing_version, build_number = ARGV
abort "Usage: ruby scripts/testflight-release.rb inspect|publish VERSION BUILD" unless
  %w[inspect publish].include?(mode) && marketing_version && build_number&.match?(/\A\d+\z/)

api = AppStoreConnect.new
app = api.get("/apps/#{APP_ID}")
raise "Unexpected bundle ID" unless app.dig("data", "attributes", "bundleId") == BUNDLE_ID
build = build_for(api, marketing_version, build_number, wait: mode == "publish")
build_id = build.fetch("id")
puts "Found #{marketing_version} (#{build_number}), processing #{build.dig('attributes', 'processingState')}."
if mode == "publish"
  publish_localizations(api, build_id)
  external_count = assign_existing_groups(api, build_id)
  puts "Assigned to #{external_count} existing external group(s); Apple may require beta review."
  detail = api.get("/builds/#{build_id}/buildBetaDetail")
  puts "External testing state: #{detail.dig('data', 'attributes', 'externalBuildState')}."
end
