# frozen_string_literal: true

# Internal groups with all-build access are populated by Apple. Posting an
# explicit build relationship while that automatic update is pending is rejected.
module TestFlightGroups
  def self.linked?(api, group_id, build_id)
    api.get("/betaGroups/#{group_id}/relationships/builds", "limit" => "200")
      .fetch("data", []).any? { |item| item["id"] == build_id }
  end

  def self.assign(api, app_id, build_id, include_external: true, timeout: 300, poll: 15,
    clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
    sleeper: ->(seconds) { sleep(seconds) }, output: $stdout)
    groups = api.get("/betaGroups", "filter[app]" => app_id, "limit" => "200").fetch("data", [])
    raise "No existing TestFlight groups found; refusing to create or invite testers" if groups.empty?
    selected = groups.select { |group| group.dig("attributes", "isInternalGroup") || include_external }
    selected.each do |group|
      group_id = group.fetch("id")
      name = group.dig("attributes", "name")
      internal = group.dig("attributes", "isInternalGroup") == true
      kind = internal ? "internal" : "external"
      automatic = internal && group.dig("attributes", "hasAccessToAllBuilds") == true
      linked = linked?(api, group_id, build_id)
      if !linked && !automatic
        api.post("/betaGroups/#{group_id}/relationships/builds",
          data: [{ type: "builds", id: build_id }])
        linked = linked?(api, group_id, build_id)
      end
      deadline = clock.call + timeout
      until linked
        raise "#{kind} group #{name}: build access was not confirmed before timeout" if clock.call >= deadline
        output.puts "#{kind} group #{name}: waiting for #{automatic ? 'automatic' : 'assigned'} build access."
        sleeper.call(poll)
        linked = linked?(api, group_id, build_id)
      end
      output.puts "#{kind} group #{name}: #{automatic ? 'automatic' : 'assigned'} build access verified."
    end
    selected.count { |group| group.dig("attributes", "isInternalGroup") == false }
  end
end
