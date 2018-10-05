class TournamentBot::Match
  include YAML::Serializable

  getter participants : Array(UInt64)
  getter time : Time
  getter id : Int32

  def initialize(@participants : Array(UInt64), @time : Time, @id : Int32)
    schedule
  end

  def to_s
    "Match ##{@id}: #{participants.map { |e| "<@#{e}>" }.join(" vs ")} on #{Utility.format_time(@time)}"
  end

  def schedule
    Utility.schedule_reminder(@participants, "A match you're in (#{@participants.map { |e| "<@#{e}>" }.join(" vs ")}, scheduled for *#{Utility.format_time(@time)}*) will begin in less than an hour!", @time - 1.hour)
  end
end
