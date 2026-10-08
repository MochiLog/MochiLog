#!/usr/bin/env ruby
# Read-only inventory; no store descriptions, versions or images are changed.
require_relative "app-store-connect-client"
require "fileutils"
api = AppStoreConnect.new
output = File.expand_path("../build/store-asset-inventory", __dir__)
FileUtils.mkdir_p(output)
{
  "library" => ["/apps/6756904240/assetLibrary", {}],
  "refdata" => ["/appAssetLibraryRefData", {}],
  "versions" => ["/apps/6756904240/appStoreVersions", {"limit" => "50", "include" => "appStoreVersionLocalizations"}]
}.each do |name, (path, params)|
  result = api.get(path, params)
  File.write(File.join(output, "#{name}.json"), JSON.pretty_generate(result))
  puts "Saved #{name} inventory"
end
