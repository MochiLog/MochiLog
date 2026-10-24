# frozen_string_literal: true
require "json"

# Invoke only after explicit user authorization. Preparation never invokes this
# module; submission requires the same build to be available in TestFlight.
module AppStoreReviewSubmission
  ACTIVE_STATES = %w[WAITING_FOR_REVIEW IN_REVIEW].freeze

  def self.submit(api, app:, version:, build:, output:, sleeper: ->(seconds) { sleep seconds })
    version_id = version.fetch("id")
    selected = api.get("/appStoreVersions/#{version_id}/build").fetch("data")
    raise "Expected valid build #{build} is not selected" unless selected &&
      selected.dig("attributes", "version") == build &&
      selected.dig("attributes", "processingState") == "VALID" &&
      selected.dig("attributes", "expired") == false
    beta = api.get("/builds/#{selected.fetch('id')}/buildBetaDetail").fetch("data")
    raise "Publish this build in external TestFlight before App Review" unless
      beta&.dig("attributes", "externalBuildState") == "IN_BETA_TESTING"

    reviews = api.get("/reviewSubmissions", "filter[app]" => app, "limit" => "200")
    raise "Unexpected submission pagination" if reviews.dig("links", "next")
    candidates = reviews.fetch("data").select do |review|
      [nil, "IOS"].include?(review.dig("attributes", "platform")) &&
        (ACTIVE_STATES + ["READY_FOR_REVIEW"]).include?(review.dig("attributes", "state"))
    end
    drafts = []
    candidates.each do |review|
      rows = items(api, review.fetch("id"))
      exact = rows.size == 1 && target_item?(rows.first, version_id)
      if ACTIVE_STATES.include?(review.dig("attributes", "state"))
        raise "Another iOS submission is active; refusing to change it" unless exact
        save(output, "submission-response.json", {"data" => review})
        puts "App Review already submitted: #{review.fetch('id')} (#{review.dig('attributes', 'state')})"
        return review
      end
      # Do not silently submit events or other app versions from an old draft.
      drafts << [review, rows] if rows.empty? || exact
    end
    matching = drafts.select { |_, rows| !rows.empty? }
    available = matching.empty? ? drafts : matching
    raise "Ambiguous review drafts; inspect before submitting" if available.size > 1
    if available.empty?
      review = api.post("/reviewSubmissions", data: {
        type: "reviewSubmissions", attributes: {platform: "IOS"},
        relationships: {app: {data: {type: "apps", id: app}}}
      }).fetch("data")
      rows = []
      save(output, "created-submission.json", {"data" => review})
    else
      review, rows = available.first
    end
    review_id = review.fetch("id")
    if rows.empty?
      added = api.post("/reviewSubmissionItems", data: {
        type: "reviewSubmissionItems",
        relationships: {
          reviewSubmission: {data: {type: "reviewSubmissions", id: review_id}},
          appStoreVersion: {data: {type: "appStoreVersions", id: version_id}}
        }
      })
      save(output, "created-submission-item.json", added)
    end
    rows = items(api, review_id)
    raise "Submission must contain only the requested app version" unless
      rows.size == 1 && target_item?(rows.first, version_id)
    current = api.get("/appStoreVersions/#{version_id}/build").fetch("data")
    raise "Selected build changed during submission preparation" unless current&.fetch("id") == selected.fetch("id")

    response = api.patch("/reviewSubmissions/#{review_id}", data: {
      type: "reviewSubmissions", id: review_id, attributes: {submitted: true}
    })
    save(output, "submission-response.json", response)
    10.times do
      review = api.get("/reviewSubmissions/#{review_id}").fetch("data")
      save(output, "submitted-review.json", {"data" => review})
      if (ACTIVE_STATES + %w[COMPLETING COMPLETE]).include?(review.dig("attributes", "state"))
        store = api.get("/appStoreVersions/#{version_id}")
        save(output, "submitted-version.json", store)
        puts "Submitted App Review: #{review_id}, #{review.dig('attributes', 'state')}, build #{build}"
        return review
      end
      sleeper.call(3)
    end
    raise "Submission requested; final state is unconfirmed. Inspect before retrying."
  end

  def self.items(api, review_id)
    response = api.get("/reviewSubmissions/#{review_id}/items", "limit" => "200", "include" => "appStoreVersion")
    raise "Unexpected review item pagination" if response.dig("links", "next")
    response.fetch("data")
  end

  def self.target_item?(item, version_id)
    item.dig("relationships", "appStoreVersion", "data", "id") == version_id
  end

  def self.save(output, filename, data)
    File.write(File.join(output, filename), JSON.pretty_generate(data))
  end
end
