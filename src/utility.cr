require "time"
require "tasker"

module TournamentBot::Utility
  def self.format_time(time : Time) : String
    Time::Format.new("%A, %-d.%-m.%Y at %I:%M%p UTC", Time::Location.fixed("UTC", 0)).format(time)
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
end
