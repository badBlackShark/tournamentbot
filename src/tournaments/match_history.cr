class TournamentBot::MatchHistory
  include YAML::Serializable

  getter matches : Array(Match)
  def initialize(matches : Array(Match))
    @matches = matches
  end

  def add(match : Match)
    @matches << match
  end
end
