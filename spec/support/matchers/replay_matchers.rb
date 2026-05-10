# Replay-level invariant matchers.
# Trading systems must guarantee determinism and non-repainting.

# Compares two replay runs. Each run is an array of events; events are
# compared by stable identifying fields (class, direction, level/index)
# rather than object identity.
RSpec::Matchers.define :match_replay do |other|
  match do |events|
    fingerprint(events) == fingerprint(other)
  end

  failure_message do |events|
    diff = fingerprint(events) - fingerprint(other)
    "replay diverged. example fingerprints absent from second run:\n#{diff.first(5).inspect}"
  end

  def fingerprint(events)
    events.map do |e|
      [
        e.class.name,
        e.respond_to?(:direction) ? e.direction : nil,
        e.respond_to?(:level)        ? e.level.round(4)        : nil,
        e.respond_to?(:swept_level)  ? e.swept_level.round(4)  : nil,
        e.respond_to?(:broken_level) ? e.broken_level.round(4) : nil,
        e.respond_to?(:candle_index) ? e.candle_index           : nil
      ]
    end
  end
end

RSpec::Matchers.define :not_repaint_structure do
  match do |snapshot_pair|
    earlier, later = snapshot_pair
    earlier.all? { |entry| later.include?(entry) }
  end

  failure_message do |snapshot_pair|
    earlier, later = snapshot_pair
    missing = earlier - later
    "expected no repainting; events emitted earlier but absent later: #{missing.inspect}"
  end
end
