# frozen_string_literal: true

module AppStoreAssetSlots
  def self.replacements(placements, desired_ids:, localization:, group:, limit: 10)
    rows = placements.select { |row|
      row.dig("attributes", "placementType") == "APP_SCREENSHOT" &&
        row.dig("attributes", "placementGroup") == group
    }
    needed = rows.size - limit + 1
    return [] unless needed.positive?
    stale = rows.reject { |row| desired_ids.include?(row.dig("relationships", "image", "data", "id")) }
    raise "Screenshot limit reached with only desired images; refusing to remove one" if stale.size < needed
    selected = stale.first(needed)
    raise "Refusing to detach a screenshot from another localization/version" unless selected.all? { |row|
      row.dig("relationships", "appStoreVersionLocalization", "data", "id") == localization
    }
    selected
  end
end
