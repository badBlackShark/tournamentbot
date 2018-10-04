class TournamentBot::Match
  include YAML::Serializable

  getter participants : Array(UInt64)
  getter time : Time
  getter id : Int32

  def initialize(@participants : Array(UInt64), @time : Time, @id : Int32)
  end

  def to_s
    "Match ##{@id}: #{participants.map { |e| "<@#{e}>" }.join(" vs ")} on #{Utility.format_time(@time)}"
  end
end
