# frozen_string_literal: true
# Authentication stays in CI secrets. Inspection never changes a store version.
require_relative "app-store-connect-client"
require "fileutils"

api = AppStoreConnect.new
app = "6756904240"
mode = ENV.fetch("RELEASE_MODE", "inspect")
version = ENV.fetch("MARKETING_VERSION", "4.0.0")
build = ENV.fetch("BUILD_NUMBER", "1060")
raise "Unknown mode" unless %w[inspect prepare].include?(mode)
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
    puts "Saved #{locale} release notes; existing store description retained"
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
