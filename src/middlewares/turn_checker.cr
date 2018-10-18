class TournamentBot::TurnChecker
  def initialize(@drafts : Hash(UInt64, Draft))
  end

  def call (payload : Discord::Message, context)
    draft = @drafts[payload.channel_id]
    if draft.next?(payload.author.id.to_u64)
      yield
    else
      context[Discord::Client].create_message(payload.channel_id, "It's not your turn right now. Please wait for <@#{draft.match.participants[draft.turn]}> to finish their turn.")
    end
  end
end
