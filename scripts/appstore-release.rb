# frozen_string_literal: true
# Authentication stays in CI secrets. Inspection never changes a store version.
require_relative "app-store-connect-client"
require "fileutils"

api = AppStoreConnect.new
app = "6756904240"
mode = ENV.fetch("RELEASE_MODE", "inspect")
version = ENV.fetch("MARKETING_VERSION", "4.0.0")
build = ENV.fetch("BUILD_NUMBER", "1060")
raise "Unknown mode" unless %w[inspect prepare verify].include?(mode)
output = File.expand_path("../build/appstore-release", __dir__)
FileUtils.mkdir_p(output)
versions = api.get("/apps/#{app}/appStoreVersions", "limit" => "50")
File.write(File.join(output, "versions.json"), JSON.pretty_generate(versions))
versions.fetch("data").each do |item|
  a = item.fetch("attributes")
  puts "Store #{a['versionString']}: #{a['appVersionState'] || a['appStoreState']} (#{item['id']})"
end
selected = versions.fetch("data").find { |v| v.dig("attributes", "versionString") == version && v.dig("attributes", "platform") == "IOS" }
builds = api.get("/builds", "filter[app]" => app, "limit" => "10", "sort" => "-uploadedDate", "include" => "preReleaseVersion")
File.write(File.join(output, "builds.json"), JSON.pretty_generate(builds))
puts "Latest uploaded builds: #{builds.fetch('data').map { |b| [b.dig('attributes', 'version'), b.dig('attributes', 'processingState')] }.inspect}"
reviews = api.get("/reviewSubmissions", "filter[app]" => app, "limit" => "50")
File.write(File.join(output, "review-submissions.json"), JSON.pretty_generate(reviews))
if selected
  id = selected.fetch("id")
  %w[appStoreVersionLocalizations appStoreReviewDetail build].each do |relationship|
    data = api.get("/appStoreVersions/#{id}/#{relationship}", relationship == "appStoreVersionLocalizations" ? {"limit" => "200"} : {})
    File.write(File.join(output, "#{relationship}.json"), JSON.pretty_generate(data))
  end
  locales = api.get("/appStoreVersions/#{id}/appStoreVersionLocalizations", "limit" => "200").fetch("data")
  locales.each do |locale|
    placements = api.get("/appStoreVersionLocalizations/#{locale.fetch('id')}/placements", "limit" => "200", "sort" => "placementGroupPosition", "include" => "image")
    File.write(File.join(output, "placements-#{locale.dig('attributes', 'locale')}.json"), JSON.pretty_generate(placements))
  end
end
# Preparing metadata never creates/submits a review request. The user presses
# the review submission button after checking the completed version in ASC.
if mode == "prepare"
  unless selected
    selected = api.post("/appStoreVersions", data: {
      type: "appStoreVersions", attributes: {platform: "IOS", versionString: version, releaseType: "AFTER_APPROVAL"},
      relationships: {app: {data: {type: "apps", id: app}}}
    }).fetch("data")
  end
  id = selected.fetch("id")
  state = selected.dig("attributes", "appVersionState") || selected.dig("attributes", "appStoreState")
  raise "Version is not editable: #{state}" unless %w[PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED METADATA_REJECTED].include?(state)
  localizations = api.get("/appStoreVersions/#{id}/appStoreVersionLocalizations", "limit" => "200").fetch("data")
  %w[ja en-US].each do |locale|
    item = localizations.find { |x| x.dig("attributes", "locale") == locale }
    raise "Missing existing #{locale} localization" unless item
    notes = File.read(File.expand_path("../fastlane/metadata/#{locale}/release_notes.txt", __dir__), encoding: "UTF-8").strip
    raise "Invalid note size" unless notes.length.between?(10, 4000)
    localization_id = item.fetch("id")
    api.patch("/appStoreVersionLocalizations/#{localization_id}", data: {type: "appStoreVersionLocalizations", id: localization_id, attributes: {whatsNew: notes, description: File.read(File.expand_path("../fastlane/metadata/#{locale}/description.txt", __dir__), encoding: "UTF-8").strip}})
    puts "Saved #{locale} release notes and description"
  end
  detail = api.get("/appStoreVersions/#{id}/appStoreReviewDetail").fetch("data")
  raise "No review contact details" unless detail
  detail_id = detail.fetch("id")
  api.patch("/appStoreReviewDetails/#{detail_id}", data: {type: "appStoreReviewDetails", id: detail_id,
    attributes: {notes: File.read(File.expand_path("../fastlane/review_notes.txt", __dir__), encoding: "UTF-8").strip}})
  uploaded = builds.fetch("data").find { |x| x.dig("attributes", "version") == build && x.dig("attributes", "processingState") == "VALID" }
  if uploaded
    prerelease_id = uploaded.dig("relationships", "preReleaseVersion", "data", "id")
    prerelease = builds.fetch("included", []).find { |x| x["type"] == "preReleaseVersions" && x["id"] == prerelease_id }
    raise "Build marketing version differs" unless prerelease&.dig("attributes", "version") == version
    api.patch("/appStoreVersions/#{id}/relationships/build", data: {type: "builds", id: uploaded.fetch("id")})
    puts "Selected #{version} (#{build})"
  else
    puts "Build #{build} is not VALID yet; metadata prepared without selecting a build"
  end
  File.write(File.join(output, "prepared-version.json"), JSON.pretty_generate(api.get("/appStoreVersions/#{id}", "include" => "build,appStoreVersionLocalizations,appStoreReviewDetail")))
  puts "Prepared #{version}; NO review submission was created or submitted"
end

if mode == "verify"
  raise "No #{version} draft exists" unless selected
  state = selected.dig("attributes", "appVersionState") || selected.dig("attributes", "appStoreState")
  raise "Version is no longer an unsubmitted draft: #{state}" unless state == "PREPARE_FOR_SUBMISSION"
  selected_build = api.get("/appStoreVersions/#{selected.fetch('id')}/build").fetch("data")
  unless selected_build&.dig("attributes", "version") == build && selected_build.dig("attributes", "processingState") == "VALID"
    raise "Expected valid build #{build} is not selected"
  end

  groups = {
    "duo" => "IPHONE_DUO_PROFILE",
    "iphone" => "IPHONE_DYNAMIC_ISLAND_LARGE_PROFILE",
    "ipad" => "IPAD_13_PROFILE",
    "watch" => "WATCH_SERIES_10_PROFILE"
  }
  locales = api.get("/appStoreVersions/#{selected.fetch('id')}/appStoreVersionLocalizations", "limit" => "200").fetch("data")
  report = {version: version, build: build, state: state, locales: {}}
  %w[ja en-US].each do |locale|
    localization = locales.find { |item| item.dig("attributes", "locale") == locale }
    raise "Missing #{locale} localization" unless localization
    {"whatsNew" => "release_notes.txt", "description" => "description.txt"}.each do |attribute, filename|
      expected = File.read(File.expand_path("../fastlane/metadata/#{locale}/#{filename}", __dir__), encoding: "UTF-8").strip
      raise "#{locale} #{attribute} differs from the committed metadata" unless localization.dig("attributes", attribute).to_s.strip == expected
    end
    placements = api.get("/appStoreVersionLocalizations/#{localization.fetch('id')}/placements",
      "limit" => "200", "sort" => "placementGroupPosition", "include" => "image,appStoreVersionLocalization")
    raise "Unexpected screenshot pagination" if placements.dig("links", "next")
    images = placements.fetch("included", []).select { |item| item["type"] == "appAssetLibraryImages" }.to_h { |item| [item.fetch("id"), item] }
    report[:locales][locale] = {}
    groups.each do |device, group|
      rows = placements.fetch("data").select do |item|
        item.dig("attributes", "placementType") == "APP_SCREENSHOT" && item.dig("attributes", "placementGroup") == group
      end
      screens = device == "watch" ? %w[01_devices 02_logs 03_health 04_metrics] : %w[01_home 02_details 03_analytics 04_settings]
      expected_order = if device == "duo"
        %w[inner outer].flat_map { |pose| screens.map { |screen| "duo_#{pose}_#{screen}.png" } }
      else
        screens.map { |screen| "#{device}_#{screen}.png" }
      end
      raise "#{locale} #{device}: expected #{expected_order.size} actual placements, got #{rows.size}" unless rows.size == expected_order.size
      filenames = rows.zip(expected_order).map do |placement, expected_filename|
        raise "#{locale} #{device}: placement is not active" unless %w[ACTIVE PARENT_PREPARE_FOR_SUBMISSION].include?(placement.dig("attributes", "state"))
        raise "#{locale} #{device}: wrong target localization" unless placement.dig("relationships", "appStoreVersionLocalization", "data", "id") == localization.fetch("id")
        image = images.fetch(placement.dig("relationships", "image", "data", "id"))
        name = image.dig("attributes", "fileName")
        raise "#{locale} #{device}: wrong image order" unless name == expected_filename
        prefix = "MochiLog #{version} #{device} #{locale} "
        raise "#{locale} #{device}: screenshots were inherited from another release" unless image.dig("attributes", "referenceName").to_s.start_with?(prefix)
        name
      end
      report[:locales][locale][device] = filenames
      puts "Verified #{version} #{locale}: #{device}, #{rows.size} ordered screenshots"
    end
  end
  File.write(File.join(output, "verified-release.json"), JSON.pretty_generate(report))
  puts "Verified build, localized metadata and all device groups, including Duo. NO review submitted."
end
