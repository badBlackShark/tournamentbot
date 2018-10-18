class TournamentBot::Draft
  getter match : Match

  # Index of participant who's turn it is in the @match.participants array
  property turn           : Int32
  property bans_left      : Int32
  property picks_left     : Int32
  property allow_votes    : Array(UInt64)
  property allow_defaults : Bool

  def initialize(@match : Match, bans_per_player : Int32, picks_per_player : Int32)
    @bans_left      = bans_per_player  * @match.participants.size
    @picks_left     = picks_per_player * @match.participants.size
    @turn           = 0
    @allow_votes    = Array(UInt64).new
    @allow_defaults = false
  end

  def next_turn
    @turn = (@turn += 1) % @match.participants.size
    @match.participants[@turn]
  end

  def next?(player : UInt64)
    @match.participants[@turn] == player
  end

  def enough_votes?
    @allow_votes.size == @match.participants.size
  end
end
