# Checks if a tournament is present in the guild a command was called in.
class TournamentBot::DraftChecker
  getter drafts : Hash(UInt64, Draft)

  def initialize(@drafts : Hash(UInt64, Draft))
  end

  def call (payload : Discord::Message, context)
    if @drafts[payload.channel_id]?
      yield
    else
      context[Discord::Client].create_message(payload.channel_id, "There is currently no running draft phase in this channel.")
    end
  end
end
