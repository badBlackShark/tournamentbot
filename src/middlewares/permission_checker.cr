# Checks if the person calling the command has the necessary permissions to do so.
class TournamentBot::PermissionChecker
  getter permission : Permission
  getter tournaments : Hash(UInt64, Tournament)

  def initialize(@tournaments : Hash(UInt64, Tournament), @permission : Permission)
  end

  def call(payload : Discord::Message, context)
    client = context[Discord::Client]
    tournament = @tournaments[context[GuildChecker::Result].id]
    user_id = payload.author.id.to_u64
    has_permission = true

    case @permission
    when Permission::None
      # Only used to check if joining people aren't already in the tournament.
      # Since only host and above are prohibited from joining, this is fine, even though it's
      # not necessarily no permission at all.
      if participant?(tournament, user_id) || host?(tournament, user_id)
        client.create_message(payload.channel_id, "You can't already be a participant or a host of the tournament **#{tournament.name}** to use this command.")
        has_permission = false
      end
    when Permission::Participant
      unless participant?(tournament, user_id)
        client.create_message(payload.channel_id, "You need to be in the tournament **#{tournament.name}** to use this command.")
        has_permission = false
      end
    when Permission::Commentator
      unless commentator?(tournament, user_id)
        client.create_message(payload.channel_id, "You need to at least have commentator level permissions in the tournament **#{tournament.name}** to use this command.")
        has_permission = false
      end
    when Permission::Volunteer
      unless volunteer?(tournament, user_id)
        client.create_message(payload.channel_id, "You need to at least have volunteer level permissions in the tournament **#{tournament.name}** to use this command.")
        has_permission = false
      end
    when Permission::Host
      unless host?(tournament, user_id)
        client.create_message(payload.channel_id, "You need to at least have host level permissions in the tournament **#{tournament.name}** to use this command.")
        has_permission = false
      end
    when Permission::Creator
      unless creator?(tournament, user_id)
        client.create_message(payload.channel_id, "You need to be the creator of the tournament **#{tournament.name}** to use this command.")
        has_permission = false
      end
    end
    yield if has_permission
  end

  def creator?(tournament : Tournament, author : UInt64)
    tournament.creator == author
  end

  def host?(tournament : Tournament, author : UInt64)
    tournament.hosts.includes?(author) || creator?(tournament, author)
  end

  def volunteer?(tournament : Tournament, author : UInt64)
    tournament.volunteers.includes?(author) || host?(tournament, author)
  end

  def commentator?(tournament : Tournament, author : UInt64)
    tournament.commentators.includes?(author) || volunteer?(tournament, author)
  end

  def participant?(tournament : Tournament, author : UInt64)
    tournament.participants.includes?(author)
  end
end
