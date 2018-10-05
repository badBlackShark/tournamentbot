require "time"
require "tasker"

module TournamentBot::Utility
  @@formatter = Time::Format.new("%A, %-d.%-m.%Y at %I:%M%p UTC", Time::Location.fixed("UTC", 0))
  @@scheduler : Tasker = Tasker.instance

  def self.store_client(client : Discord::Client)
    @@client = client
  end

  def self.format_time(time : Time) : String
    @@formatter.format(time)
  end

  def self.schedule_reminder(targets : Array(UInt64), message : String, time : Time)
    @@scheduler.at(time) do
      targets.each do |target|
        channel = @@client.try &.cache.try &.resolve_dm_channel(target)
        if channel
          @@client.try &.create_message(channel, message)
        end
      end
    end
  end
end
