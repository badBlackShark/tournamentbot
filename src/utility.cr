require "time"
require "tasker"
require "levenshtein"

module TournamentBot::Utility
  def self.format_time(time : Time) : String
    Time::Format.new("%A, %-d.%-m.%Y at %I:%M %p UTC", Time::Location.fixed("UTC", 0)).format(time)
  end

  def self.schedule_reminder(targets : Array(UInt64), message : String, time : Time)
    Tasker.instance.at(time) do
      targets.each do |target|
        channel = TournamentBot.bot().cache.resolve_dm_channel(target)
        if channel
          TournamentBot.bot().client.create_message(channel, message)
        end
      end
    end
  end

  # Very basic adaptation of https://github.com/seamusabshere/fuzzy_match
  def self.fuzzy_match(needle : String, haystack : Array(String), min : Float? = nil)
    best_match = ""
    best_distance = 0.0

    haystack.each do |h|
      distance = dice_coefficient(needle, h)
      next if min && distance < min
      if best_distance < distance
        best_distance = distance
        best_match = h
      elsif best_distance != 0.0 && distance == best_distance
        # If the dice coefficient is the same, resolve with Levenshtein distance.
        best_match = h if Levenshtein.distance(needle, best_match) < Levenshtein.distance(needle, h)
      end
    end

    return best_match
  end

  private def self.dice_coefficient(s1 : String, s2 : String)
    return 1.0 if s1 == s2

    b1 = get_bigrams(s1)
    b2 = get_bigrams(s2)
    hits = 0
    size = b1.size + b2.size

    b1.each do |p1|
      0.upto(b2.size - 1) do |i|
        if p1 == b2[i]
          hits += 1
          b2.delete_at(i)
          break
        end
      end
    end

    return (2.0 * hits) / (size)
  end

  private def self.get_bigrams(string : String)
    s = string.downcase
    return (0..s.size - 2).map { |i| s[i,2] }.reject { |p| p.includes?(" ") }
  end
end
