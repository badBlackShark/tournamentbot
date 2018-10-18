class TournamentBot::BanChecker
  def initialize(@drafts : Hash(UInt64, Draft), @should_be_zero : Bool)
  end

  def call (payload : Discord::Message, context)
    is_zero = (@drafts[payload.channel_id].bans_left == 0)
    if is_zero == @should_be_zero
      yield
    elsif is_zero && !@should_be_zero
      context[Discord::Client].create_message(payload.channel_id, "The ban stage has already finished, so you can't use this command anymore.")
    elsif !is_zero && @should_be_zero
      context[Discord::Client].create_message(payload.channel_id, "The ban stage hasn't finished yet, so you can't use this command yet.")
    end
  end
end
