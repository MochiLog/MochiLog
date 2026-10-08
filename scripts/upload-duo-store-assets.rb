#!/usr/bin/env ruby
# Add Duo images without deleting assets or changing existing store text/builds.
require_relative "app-store-connect-client"
require "digest"
require "fileutils"
api = AppStoreConnect.new
app = "6756904240"
version = ENV.fetch("STORE_VERSION", "3.2.2")
result_path = File.expand_path("../build/store-asset-inventory/duo-upload.json", __dir__)
FileUtils.mkdir_p(File.dirname(result_path))
results = []
def all(api, path, params = {})
  rows = []
  loop do
    response = api.get(path, params)
    rows.concat(response.fetch("data"))
    next_url = response.dig("links", "next")
    break if next_url.nil?
    uri = URI(next_url)
    raise "Unexpected pagination host" unless uri.host == "api.appstoreconnect.apple.com"
    path = uri.path.delete_prefix("/v1")
    params = URI.decode_www_form(uri.query.to_s).to_h
  end
  rows
end
begin
  refdata = api.get("/appAssetLibraryRefData").fetch("data").flat_map { |x| x.dig("attributes", "placementProfileGroups") || [] }
  raise "Apple does not support Duo placement" unless refdata.any? { |x| x["placementProfileGroupId"] == "IPHONE_DUO_PROFILE" }
  library = api.get("/apps/#{app}/assetLibrary").fetch("data").fetch("id")
  selected = all(api, "/apps/#{app}/appStoreVersions", "limit" => "50").find { |x| x.dig("attributes", "platform") == "IOS" && x.dig("attributes", "versionString") == version }
  raise "Store version #{version} does not exist; no version is created automatically" unless selected
  editable = %w[PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED METADATA_REJECTED].include?(selected.dig("attributes", "appStoreState"))
  puts "Store version #{version} is #{selected.dig('attributes', 'appStoreState')}; saving images to the library only" unless editable
  locales = all(api, "/appStoreVersions/#{selected.fetch('id')}/appStoreVersionLocalizations", "limit" => "200").to_h { |x| [x.dig("attributes", "locale"), x.fetch("id")] }
  existing = all(api, "/appAssetLibraries/#{library}/images", "limit" => "200")
  %w[ja en-US].each do |locale|
    localization = locales.fetch(locale)
    files = Dir[File.expand_path("../fastlane/store-assets/duo/#{locale}/duo_*.png", __dir__)].sort
    raise "Missing complete Duo screenshot set for #{locale}" unless files.size.between?(4, 10)
    %w[01_home 02_details 03_analytics 04_settings].each { |screen| raise "Missing #{screen}" unless files.any? { |f| f.end_with?("#{screen}.png") } }
    files.each do |file|
      bytes = File.binread(file)
      raise "Invalid PNG" unless bytes.start_with?("\x89PNG\r\n\x1a\n".b)
      width, height = bytes[16, 8].unpack("NN")
      raise "Unexpected Duo dimensions" unless [[1398,2034],[2007,2853]].include?([width,height])
      raise "Duo image must be RGB, without alpha" unless bytes.getbyte(25) == 2
      reference = "Duo #{locale} #{File.basename(file)} #{Digest::SHA256.hexdigest(bytes)[0,16]}"
      image = existing.find { |x| x.dig("attributes", "referenceName") == reference }
      unless image
        image = api.post("/appAssetLibraryImages", data: {type: "appAssetLibraryImages", attributes: {
          category: "APP_SCREENSHOTS_AND_PREVIEWS", fileName: File.basename(file), fileSize: bytes.bytesize, referenceName: reference},
          relationships: {assetLibrary: {data: {type: "appAssetLibraries", id: library}}}}).fetch("data")
        existing << image
      end
      if image.dig("attributes", "state") == "AWAITING_UPLOAD"
        image = api.get("/appAssetLibraryImages/#{image.fetch('id')}").fetch("data")
        image.dig("attributes", "uploadOperations").each do |operation|
          uri = URI(operation.fetch("url"))
          raise "Upload URL is not HTTPS" unless uri.scheme == "https"
          request = Net::HTTP.const_get(operation.fetch("method").capitalize).new(uri)
          operation.fetch("requestHeaders", []).each { |header| request[header.fetch("name")] = header.fetch("value") }
          request.body = bytes.byteslice(operation.fetch("offset"), operation.fetch("length"))
          response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 20, read_timeout: 60) { |http| http.request(request) }
          raise "Image upload returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
        end
        api.patch("/appAssetLibraryImages/#{image.fetch('id')}", data: {type: "appAssetLibraryImages", id: image.fetch("id"), attributes: {uploaded: true}})
      end
      id = image.fetch("id")
      30.times do
        image = api.get("/appAssetLibraryImages/#{id}").fetch("data")
        break unless %w[AWAITING_UPLOAD UPLOAD_COMPLETE].include?(image.dig("attributes", "state"))
        sleep 3
      end
      state = image.dig("attributes", "state")
      raise "Image #{File.basename(file)} is #{state}" if %w[FAILED AWAITING_UPLOAD UPLOAD_COMPLETE].include?(state)
      result = {locale: locale, filename: File.basename(file), imageID: id, imageState: state, targetVersion: version}
      unless editable
        results << result.merge(placementState: "WAITING_FOR_EDITABLE_VERSION")
        File.write(result_path, JSON.pretty_generate(results))
        puts "Saved #{locale}/#{File.basename(file)} to library (#{state})"
        next
      end
      placements = all(api, "/appAssetLibraryImages/#{id}/placements", "limit" => "200", "include" => "appStoreVersionLocalization")
      placement = placements.find { |x| x.dig("attributes", "placementGroup") == "IPHONE_DUO_PROFILE" && x.dig("relationships", "appStoreVersionLocalization", "data", "id") == localization }
      placement ||= api.post("/appAssetLibraryPlacements", data: {type: "appAssetLibraryPlacements", attributes: {
        placementType: "APP_SCREENSHOT", placementGroup: "IPHONE_DUO_PROFILE"}, relationships: {
        image: {data: {type: "appAssetLibraryImages", id: id}},
        appStoreVersionLocalization: {data: {type: "appStoreVersionLocalizations", id: localization}}}}).fetch("data")
      results << result.merge(placementID: placement.fetch("id"), placementState: placement.dig("attributes", "state"))
      puts "Registered #{locale}/#{File.basename(file)} (#{state})"
      File.write(result_path, JSON.pretty_generate(results))
    end
  end
ensure
  File.write(result_path, JSON.pretty_generate(results))
end
puts "Saved #{results.size} Duo images; #{results.count { |x| x[:placementID] }} placed on version #{version}. No review or stable release was submitted."
