require "time"

module TournamentBot::Utility
  @@formatter = Time::Format.new("%A, %-d.%-m.%Y at %I:%M%p UTC", Time::Location.fixed("UTC", 0))

  def self.format_time(time : Time) : String
    @@formatter.format(time)
  end
end
