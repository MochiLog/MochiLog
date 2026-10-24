#!/usr/bin/env ruby
# Register verified screenshots on an editable store version. Never submits review.
require_relative "app-store-connect-client"
require "digest"
require "fileutils"
api = AppStoreConnect.new
app = "6756904240"
version = ENV.fetch("STORE_VERSION", "4.0.0")
device = ENV.fetch("STORE_DEVICE", "duo")
groups = {"duo" => "IPHONE_DUO_PROFILE", "iphone" => "IPHONE_DYNAMIC_ISLAND_LARGE_PROFILE", "ipad" => "IPAD_13_PROFILE", "watch" => "WATCH_SERIES_10_PROFILE"}
group = groups.fetch(device)
dimensions = {"duo" => [[1398,2034],[2007,2853]], "iphone" => [[1320,2868]], "ipad" => [[2064,2752]], "watch" => [[416,496]]}.fetch(device)
result_path = File.expand_path("../build/store-asset-inventory/#{device}-upload.json", __dir__)
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
  raise "Apple does not support #{group} placement" unless refdata.any? { |x| x["placementProfileGroupId"] == group }
  library = api.get("/apps/#{app}/assetLibrary").fetch("data").fetch("id")
  selected = all(api, "/apps/#{app}/appStoreVersions", "limit" => "50").find { |x| x.dig("attributes", "platform") == "IOS" && x.dig("attributes", "versionString") == version }
  raise "Store version #{version} does not exist; no version is created automatically" unless selected
  editable = %w[PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED METADATA_REJECTED].include?(selected.dig("attributes", "appStoreState"))
  raise "Store version #{version} is not editable; create an editable version before registering screenshots" unless editable
  locales = all(api, "/appStoreVersions/#{selected.fetch('id')}/appStoreVersionLocalizations", "limit" => "200").to_h { |x| [x.dig("attributes", "locale"), x.fetch("id")] }
  existing = all(api, "/appAssetLibraries/#{library}/images", "limit" => "200")
  uploads = []
  %w[ja en-US].each do |locale|
    localization = locales.fetch(locale)
    files = Dir[File.expand_path("../fastlane/store-assets/#{device}/#{locale}/#{device}_*.png", __dir__)].sort
    raise "Missing complete #{device} screenshot set for #{locale}" unless files.size.between?(4, 10)
    (device == "watch" ? %w[01_devices 02_logs 03_health 04_metrics] : %w[01_home 02_details 03_analytics 04_settings]).each { |screen| raise "Missing #{screen}" unless files.any? { |f| f.end_with?("#{screen}.png") } }
    if device == "duo"
      %w[inner outer].each do |pose|
        %w[01_home 02_details 03_analytics 04_settings].each do |screen|
          raise "Missing Duo #{pose} #{screen} for #{locale}" unless files.any? { |file| File.basename(file) == "duo_#{pose}_#{screen}.png" }
        end
      end
    end
    files.each do |file|
      bytes = File.binread(file)
      raise "Invalid PNG" unless bytes.start_with?("\x89PNG\r\n\x1a\n".b)
      width, height = bytes[16, 8].unpack("NN")
      raise "Unexpected #{device} dimensions" unless dimensions.include?([width,height])
      raise "Screenshot must be RGB, without alpha" unless bytes.getbyte(25) == 2
      reference = "MochiLog #{version} #{device} #{locale} #{File.basename(file)} #{Digest::SHA256.hexdigest(bytes)[0,16]}"
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
      uploads << [locale, localization, file, image.fetch("id")]
    end
  end
  # Queue every locale before waiting, so Apple's asynchronous image processing
  # happens concurrently rather than adding a separate wait for every file.
  processing_deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 20 * 60
  uploads.each do |locale, localization, file, id|
      240.times do |attempt|
        image = api.get("/appAssetLibraryImages/#{id}").fetch("data")
        File.write(File.join(File.dirname(result_path), "#{device}-latest-image.json"), JSON.pretty_generate(image))
        # Apple's deployed API can briefly report COMPLETE before attaching
        # the image specification. It is still processing, not ready to place.
        break unless %w[AWAITING_UPLOAD UPLOAD_COMPLETE COMPLETE].include?(image.dig("attributes", "state"))
        raise "Store image processing exceeded the run deadline; reservations are retained for retry" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= processing_deadline
        puts "Waiting for #{locale}/#{File.basename(file)} processing: #{image.dig('attributes', 'state')}" if (attempt % 10).zero?
        sleep 3
      end
      state = image.dig("attributes", "state")
      ready_states = %w[PREPARE_FOR_SUBMISSION READY_FOR_REVIEW WAITING_FOR_REVIEW IN_REVIEW ACCEPTED APPROVED]
      raise "Image #{File.basename(file)} is not ready: #{state}" unless ready_states.include?(state)
      result = {device: device, group: group, locale: locale, filename: File.basename(file), imageID: id, imageState: state, targetVersion: version}
      unless editable
        results << result.merge(placementState: "WAITING_FOR_EDITABLE_VERSION")
        File.write(result_path, JSON.pretty_generate(results))
        puts "Saved #{locale}/#{File.basename(file)} to library (#{state})"
        next
      end
      placements = all(api, "/appAssetLibraryImages/#{id}/placements", "limit" => "200", "include" => "appStoreVersionLocalization")
      placement = placements.find { |x| x.dig("attributes", "placementGroup") == group && x.dig("relationships", "appStoreVersionLocalization", "data", "id") == localization }
      placement ||= api.post("/appAssetLibraryPlacements", data: {type: "appAssetLibraryPlacements", attributes: {
        placementType: "APP_SCREENSHOT", placementGroup: group}, relationships: {
        image: {data: {type: "appAssetLibraryImages", id: id}},
        appStoreVersionLocalization: {data: {type: "appStoreVersionLocalizations", id: localization}}}}).fetch("data")
      saved_placement = nil
      30.times do
        saved_placement = api.get("/appAssetLibraryPlacements/#{placement.fetch('id')}", "include" => "appStoreVersionLocalization,image").fetch("data")
        File.write(File.join(File.dirname(result_path), "#{device}-latest-placement.json"), JSON.pretty_generate(saved_placement))
        break if %w[ACTIVE PARENT_PREPARE_FOR_SUBMISSION].include?(saved_placement.dig("attributes", "state"))
        sleep 3
      end
      raise "Placement has wrong device group" unless saved_placement.dig("attributes", "placementGroup") == group
      raise "Placement has wrong store localization" unless saved_placement.dig("relationships", "appStoreVersionLocalization", "data", "id") == localization
      # The deployed API can return ACTIVE while newer API documentation uses
      # PARENT_PREPARE_FOR_SUBMISSION. Both require the verified editable parent,
      # ready image and exact localization/group relationships checked above.
      raise "Placement has not finished processing: #{saved_placement.dig('attributes', 'state')}" unless %w[ACTIVE PARENT_PREPARE_FOR_SUBMISSION].include?(saved_placement.dig("attributes", "state"))
      results << result.merge(placementID: placement.fetch("id"), placementState: saved_placement.dig("attributes", "state"))
      puts "Registered #{locale}/#{File.basename(file)} (#{state})"
      File.write(result_path, JSON.pretty_generate(results))
  end
ensure
  File.write(result_path, JSON.pretty_generate(results))
end
if editable
    %w[ja en-US].each do |locale|
      localization = locales.fetch(locale)
      selected_ids = results.select { |x| x[:locale] == locale }.map { |x| x.fetch(:placementID) }
      current = all(api, "/appStoreVersionLocalizations/#{localization}/placements", "limit" => "200", "sort" => "placementGroupPosition")
      same_group = current.select { |x| x.dig("attributes", "placementType") == "APP_SCREENSHOT" && x.dig("attributes", "placementGroup") == group }
      extra_ids = same_group.map { |x| x.fetch("id") } - selected_ids
      api.post("/appAssetLibraryPlacementOrderingRequests", data: {type: "appAssetLibraryPlacementOrderingRequests", attributes: {placementGroup: group}, relationships: {
        orderedPlacements: {data: (selected_ids + extra_ids).map { |id| {type: "appAssetLibraryPlacements", id: id} }},
        appStoreVersionLocalization: {data: {type: "appStoreVersionLocalizations", id: localization}}}})
      saved = all(api, "/appStoreVersionLocalizations/#{localization}/placements", "limit" => "200", "sort" => "placementGroupPosition")
        .select { |x| x.dig("attributes", "placementType") == "APP_SCREENSHOT" && x.dig("attributes", "placementGroup") == group }
      raise "Screenshot order or placement did not persist" unless saved.first(selected_ids.size).map { |x| x.fetch("id") } == selected_ids
      # Only this draft version's same-device references are replaced. Library
      # images and all placements on the public version remain untouched.
      extra_ids.each { |id| api.delete("/appAssetLibraryPlacements/#{id}") }
      final = all(api, "/appStoreVersionLocalizations/#{localization}/placements", "limit" => "200", "sort" => "placementGroupPosition")
        .select { |x| x.dig("attributes", "placementType") == "APP_SCREENSHOT" && x.dig("attributes", "placementGroup") == group }
      raise "Final screenshot set differs" unless final.map { |x| x.fetch("id") } == selected_ids
      puts "Verified #{locale}: #{selected_ids.size} #{device} screenshots on #{version} in display order"
    end
end
puts "Saved #{results.size} #{device} images; #{results.count { |x| x[:placementID] }} placed on version #{version}. No review or stable release was submitted."
