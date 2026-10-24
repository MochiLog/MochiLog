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
end
raise "Mutation modes are not enabled until inspection has completed" unless mode == "inspect"
