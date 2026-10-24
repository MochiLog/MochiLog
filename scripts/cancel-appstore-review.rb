# frozen_string_literal: true
# Explicit withdrawal only. Never creates or submits an App Review request.
module AppStoreReviewWithdrawal
  EDITABLE_STATES = %w[PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED METADATA_REJECTED].freeze
  ACTIVE_STATES = %w[WAITING_FOR_REVIEW IN_REVIEW].freeze

  def self.cancel(api, app:, version:, output:)
    raise "No selected store version" unless version
    id = version.fetch("id")
    state = version.dig("attributes", "appVersionState") || version.dig("attributes", "appStoreState")
    if EDITABLE_STATES.include?(state)
      puts "Version is already editable: #{state}; no review canceled"
      return
    end
    raise "Refusing withdrawal in state #{state}" unless ACTIVE_STATES.include?(state)

    reviews = api.get("/reviewSubmissions", "filter[app]" => app, "limit" => "200")
    raise "Unexpected submission pagination" if reviews.dig("links", "next")
    matches = reviews.fetch("data").select do |review|
      next false unless review.dig("attributes", "platform") == "IOS" &&
        ACTIVE_STATES.include?(review.dig("attributes", "state"))
      items = api.get("/reviewSubmissions/#{review.fetch('id')}/items", "limit" => "200", "include" => "appStoreVersion")
      raise "Unexpected review item pagination" if items.dig("links", "next")
      rows = items.fetch("data")
      target_items = rows.select { |item| item.dig("relationships", "appStoreVersion", "data", "id") == id }
      next false if target_items.empty?
      raise "Submission includes other items; refusing to cancel those implicitly" unless rows.size == target_items.size
      true
    end
    raise "Expected exactly one submission for this version, got #{matches.size}" unless matches.size == 1
    review_id = matches.first.fetch("id")
    response = api.patch("/reviewSubmissions/#{review_id}", data: {
      type: "reviewSubmissions", id: review_id, attributes: {canceled: true}
    })
    File.write(File.join(output, "withdrawal-response.json"), JSON.pretty_generate(response))
    30.times do
      current = api.get("/appStoreVersions/#{id}")
      File.write(File.join(output, "withdrawn-version.json"), JSON.pretty_generate(current))
      current_state = current.dig("data", "attributes", "appVersionState") ||
        current.dig("data", "attributes", "appStoreState")
      if EDITABLE_STATES.include?(current_state)
        puts "Withdrawn #{version.dig('attributes', 'versionString')}: #{current_state}; NO resubmission"
        return
      end
      sleep 3
    end
    raise "Withdrawal requested but editable status not yet confirmed; inspect before retrying"
  end
end
