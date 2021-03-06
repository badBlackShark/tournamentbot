class TournamentBot::BanChecker
  def initialize(@drafts : Hash(UInt64, Draft), @ban_stage_complete : Bool)
  end

  def call(payload : Discord::Message, context)
    bans_left = @drafts[payload.channel_id].bans_left
    return yield if bans_left.zero? && @ban_stage_complete

    if bans_left.zero? && !@ban_stage_complete
      context[Discord::Client].create_message(payload.channel_id, "The ban stage has already finished, so you can't use this command anymore.")
    elsif !bans_left.zero? && @ban_stage_complete
      context[Discord::Client].create_message(payload.channel_id, "The ban stage hasn't finished yet, so you can't use this command yet.")
    else
      yield
    end
  end
end
