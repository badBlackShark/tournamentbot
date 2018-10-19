class TournamentBot::MatchHistory
  include YAML::Serializable

  getter matches : Array(Match)
  def initialize(matches : Array(Match))
    @matches = matches
  end

  def add(match : Match)
    @matches.push(match)
  end

  def picked_map?(player : UInt64, map : String)
    return @matches.find do |match|
      match.picks[player]?.try &.includes?(map)
    end
  end
end
