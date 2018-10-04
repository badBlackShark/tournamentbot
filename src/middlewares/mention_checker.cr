# Checks if a certain amount of mentions are present in a message.
class TournamentBot::MentionChecker
  getter min_mentions : Int32?
  getter max_mentions : Int32?

  def initialize(@min_mentions : Int32? = nil, @max_mentions : Int32? = nil)
  end

  # Checks if a command was called in a guild (as opposed to a DM channel.)
  def call (payload : Discord::Message, context)
    min_mentions, max_mentions = @min_mentions, @max_mentions

    if min_mentions && payload.mentions.size < min_mentions
      context[Discord::Client].create_message(payload.channel_id, "You need to mention at least #{min_mentions} user(s) to use this command.")
    elsif max_mentions && payload.mentions.size > max_mentions
      context[Discord::Client].create_message(payload.channel_id, "You can't mention more than #{max_mentions} user(s) to use this command.")
    else
      yield
    end
  end
end
