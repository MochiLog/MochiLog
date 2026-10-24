# frozen_string_literal: true
require "minitest/autorun"
require "tmpdir"
require_relative "submit-appstore-review"

class AppStoreReviewSubmissionTest < Minitest::Test
  class API
    attr_reader :mutations
    attr_accessor :beta_state, :reviews, :rows, :selected_number, :change_build

    def initialize
      @mutations, @reviews, @rows = [], [], []
      @beta_state, @selected_number, @submitted = "IN_BETA_TESTING", "1063", false
      @build_reads = 0
    end

    def get(path, params = {})
      case path
      when "/appStoreVersions/version/build"
        @build_reads += 1
        {"data" => {"id" => (@change_build && @build_reads > 1 ? "other" : "build"),
          "attributes" => {"version" => @selected_number, "processingState" => "VALID", "expired" => false}}}
      when "/builds/build/buildBetaDetail"
        {"data" => {"attributes" => {"externalBuildState" => @beta_state}}}
      when "/reviewSubmissions"
        {"data" => @reviews}
      when %r{\A/reviewSubmissions/[^/]+/items\z}
        raise "Request the version relationship explicitly" unless params["include"] == "appStoreVersion"
        {"data" => @rows}
      when "/reviewSubmissions/review"
        {"data" => {"id" => "review", "attributes" => {"state" => @submitted ? "WAITING_FOR_REVIEW" : "READY_FOR_REVIEW"}}}
      when "/appStoreVersions/version"
        {"data" => {"id" => "version", "attributes" => {"appVersionState" => "WAITING_FOR_REVIEW"}}}
      else
        raise "Unexpected API request: #{path}"
      end
    end

    def post(path, body)
      @mutations << [path, body]
      if path == "/reviewSubmissionItems"
        @rows = [{"relationships" => {"appStoreVersion" => {"data" => {"id" => "version"}}}}]
      end
      {"data" => {"id" => path == "/reviewSubmissions" ? "review" : "item"}}
    end

    def patch(path, body)
      @mutations << [path, body]
      @submitted = true
      get(path)
    end
  end

  def submit(api)
    Dir.mktmpdir("mochilog-review-test") do |directory|
      capture_io do
        AppStoreReviewSubmission.submit(api, app: "app", version: {"id" => "version"},
          build: "1063", output: directory, sleeper: ->(_) {})
      end
    end
  end

  def test_only_requested_version_is_submitted_after_testflight
    api = API.new
    submit(api)
    assert_equal ["/reviewSubmissions", "/reviewSubmissionItems", "/reviewSubmissions/review"], api.mutations.map(&:first)
    assert_equal({submitted: true}, api.mutations.last.last.fetch(:data).fetch(:attributes))
  end

  def test_unpublished_beta_or_wrong_build_cannot_mutate
    api = API.new
    api.beta_state = "WAITING_FOR_BETA_REVIEW"
    assert_raises(RuntimeError) { submit(api) }
    assert_empty api.mutations
    api = API.new
    api.selected_number = "1062"
    assert_raises(RuntimeError) { submit(api) }
    assert_empty api.mutations
  end

  def test_active_foreign_submission_is_never_modified
    api = API.new
    api.reviews = [{"id" => "review", "attributes" => {"platform" => "IOS", "state" => "IN_REVIEW"}}]
    api.rows = [{"relationships" => {"appStoreVersion" => {"data" => {"id" => "other"}}}}]
    assert_raises(RuntimeError) { submit(api) }
    assert_empty api.mutations
  end

  def test_existing_target_draft_is_reused_without_adding_another_item
    api = API.new
    api.reviews = [{"id" => "review", "attributes" => {"platform" => "IOS", "state" => "READY_FOR_REVIEW"}}]
    api.rows = [{"relationships" => {"appStoreVersion" => {"data" => {"id" => "version"}}}}]
    submit(api)
    assert_equal ["/reviewSubmissions/review"], api.mutations.map(&:first)
  end

  def test_already_submitted_target_is_idempotent
    api = API.new
    api.reviews = [{"id" => "review", "attributes" => {"platform" => "IOS", "state" => "WAITING_FOR_REVIEW"}}]
    api.rows = [{"relationships" => {"appStoreVersion" => {"data" => {"id" => "version"}}}}]
    submit(api)
    assert_empty api.mutations
  end

  def test_changed_build_is_not_submitted
    api = API.new
    api.change_build = true
    assert_raises(RuntimeError) { submit(api) }
    refute api.mutations.any? { |_, body| body.dig(:data, :attributes, :submitted) }
  end
end
