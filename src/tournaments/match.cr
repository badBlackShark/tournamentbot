class TournamentBot::Match
  include YAML::Serializable

  getter participants : Array(UInt64)
  getter time : Time
  getter id : Int32
  # Every match will have a dedicated draft pick channel created for it.
  # This gets stored so the match can be deleted later
  property channel : UInt64

  def initialize(@participants : Array(UInt64), @time : Time, @id : Int32)
    @channel = 0
    schedule
  end

  def to_s
    "Match ##{@id}: #{participants.map { |e| "<@#{e}>" }.join(" vs ")} on #{Utility.format_time(@time)}"
  end

  def schedule
    Utility.schedule_reminder(@participants, "A match you're in (#{@participants.map { |e| "<@#{e}>" }.join(" vs ")}, scheduled for *#{Utility.format_time(@time)}*) will begin in less than an hour!", @time - 1.hour)
  end
end
