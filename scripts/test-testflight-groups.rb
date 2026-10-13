#!/usr/bin/env ruby
# frozen_string_literal: true
require "minitest/autorun"
require "stringio"
require_relative "testflight-groups"

class TestFlightGroupsTest < Minitest::Test
  class API
    attr_reader :posts
    def initialize(groups, pending: {})
      @groups, @pending, @posts, @assigned = groups, pending.dup, [], {}
    end
    def get(path, _params = {})
      return { "data" => @groups } if path == "/betaGroups"
      id = path.split("/")[2]
      remaining = @pending.fetch(id, 0)
      @pending[id] = remaining - 1 if remaining.positive?
      linked = @assigned[id] || (remaining.zero? && @groups.find { |g| g["id"] == id }.dig("attributes", "hasAccessToAllBuilds"))
      { "data" => linked ? [{ "id" => "build" }] : [] }
    end
    def post(path, body)
      @posts << [path, body]
      @assigned[path.split("/")[2]] = true
    end
  end

  def group(id, internal:, automatic: false)
    { "id" => id, "attributes" => { "name" => id,
      "isInternalGroup" => internal, "hasAccessToAllBuilds" => automatic } }
  end

  def assign(api, **options)
    time = 0
    TestFlightGroups.assign(api, "app", "build", **options, timeout: 30, poll: 10,
      clock: -> { time }, sleeper: ->(seconds) { time += seconds }, output: StringIO.new)
  end

  def test_automatic_propagation_never_posts_an_internal_build
    api = API.new([group("internal", internal: true, automatic: true), group("external", internal: false)],
      pending: { "internal" => 2 })
    assert_equal 1, assign(api)
    assert_equal ["/betaGroups/external/relationships/builds"], api.posts.map(&:first)
  end

  def test_unconfirmed_automatic_access_is_a_failure
    api = API.new([group("internal", internal: true, automatic: true)], pending: { "internal" => 100 })
    assert_raises(RuntimeError) { assign(api) }
    assert_empty api.posts
  end

  def test_manual_internal_groups_are_assigned_and_external_can_be_excluded
    api = API.new([group("internal", internal: true), group("external", internal: false)])
    assert_equal 0, assign(api, include_external: false)
    assert_equal ["/betaGroups/internal/relationships/builds"], api.posts.map(&:first)
  end

  def test_no_groups_never_creates_a_group_or_invites_testers
    api = API.new([])
    assert_raises(RuntimeError) { assign(api) }
    assert_empty api.posts
  end
end
