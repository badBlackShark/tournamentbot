require "yaml"

module TournamentBot::TournamentManager
  @@tournaments = Hash(UInt64, Tournament).new

  def self.tournaments
    @@tournaments
  end

  def self.save(tournament : Tournament)
    File.open("./tournament-files/#{tournament.guild}.yml", "w") { |f| tournament.to_yaml(f) }
  end

  @[Discord::Plugin::Options()]
  class TournamentBot::TournamentCreator
    include Discord::Plugin

    def initialize
      load_tournaments
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!create"),
        GuildChecker.new,
        ArgumentChecker.new
      }
    )]
    def create(payload, ctx)
      name = ctx[ArgumentChecker::Result].args.join(" ")
      author = payload.author.id.to_u64
      guild = ctx[GuildChecker::Result].id

      if TournamentManager.tournaments[guild]?
        client.create_message(payload.channel_id, "There is already a tournament being ran on this server. More than that is currently not supported.")
        return
      end

      tournament = Tournament.new(author, guild, name)
      embed = tournament.to_embed

      TournamentManager.tournaments[guild] = tournament

      TournamentManager.save(tournament)

      client.create_message(payload.channel_id,"", embed)
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!tournament"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments)
      }
    )]
    def tournament(payload, ctx)
      guild = ctx[GuildChecker::Result].id

      client.create_message(payload.channel_id,"", TournamentManager.tournaments[guild].to_embed)
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!delete"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Creator)
      }
    )]
    def delete(payload, ctx)
      guild = ctx[GuildChecker::Result].id

      name = TournamentManager.tournaments[guild].name
      TournamentBot.bot.client.delete_guild_role(guild, TournamentManager.tournaments[guild].draft_role)
      TournamentManager.tournaments.delete(guild)
      File.delete("./tournament-files/#{guild}.yml")

      client.create_message(payload.channel_id, "The tournament *#{name}* was successfully deleted.")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!addHost"),
        GuildChecker.new,
        MentionChecker.new(1),
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Creator)
      }
    )]
    def add_host(payload, ctx)
      guild = ctx[GuildChecker::Result].id

      hosts = Array(String).new

      payload.mentions.each do |host|
        if ctx[PermissionChecker].host?(TournamentManager.tournaments[guild], host.id.to_u64)
          client.create_message(payload.channel_id, "#{host.username}##{host.discriminator} is already a host of this tournament.")
          next
        end

        TournamentManager.tournaments[guild].hosts << host.id.to_u64
        hosts << "**#{host.username}##{host.discriminator}**"
      end
      TournamentManager.save(TournamentManager.tournaments[guild])

      client.create_message(payload.channel_id, "Successfully added #{hosts.join(", ")} to the list of hosts.") unless hosts.empty?
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!removeHost"),
        GuildChecker.new,
        MentionChecker.new(1),
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Creator)
      }
    )]
    def remove_host(payload, ctx)
      guild = ctx[GuildChecker::Result].id

      hosts = Array(String).new

      payload.mentions.each do |host|
        unless ctx[PermissionChecker].creator?(TournamentManager.tournaments[guild], host.id.to_u64)
          client.create_message(payload.channel_id, "#{host.username}##{host.discriminator} isn't a host of this tournament.")
          next
        end

        if TournamentManager.tournaments[guild].creator == host.id.to_u64
          client.create_message(payload.channel_id, "You can't remove yourself from the team of hosts.")
          next
        end

        TournamentManager.tournaments[guild].hosts.delete(host.id.to_u64)
        hosts << "**#{host.username}##{host.discriminator}**"
      end
      TournamentManager.save(TournamentManager.tournaments[guild])

      client.create_message(payload.channel_id, "Successfully removed #{hosts.join(", ")} from the list of hosts.") unless hosts.empty?
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!addVolunteer"),
        GuildChecker.new,
        MentionChecker.new(1),
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Creator)
      }
    )]
    def add_volunteer(payload, ctx)
      guild = ctx[GuildChecker::Result].id

      volunteers = Array(String).new

      payload.mentions.each do |vol|
        if ctx[PermissionChecker].volunteer?(TournamentManager.tournaments[guild], vol.id.to_u64)
          client.create_message(payload.channel_id, "#{vol.username}##{vol.discriminator} is already a staff member of this tournament.")
          next
        end

        TournamentManager.tournaments[guild].volunteers << vol.id.to_u64
        volunteers << "**#{vol.username}##{vol.discriminator}**"
      end
      TournamentManager.save(TournamentManager.tournaments[guild])

      client.create_message(payload.channel_id, "Successfully added #{volunteers.join(", ")} to the list of volunteers.") unless volunteers.empty?
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!removeVolunteer"),
        GuildChecker.new,
        MentionChecker.new(1),
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Creator)
      }
    )]
    def remove_volunteer(payload, ctx)
      guild = ctx[GuildChecker::Result].id

      volunteers = Array(String).new

      payload.mentions.each do |vol|
        unless ctx[PermissionChecker].volunteer?(TournamentManager.tournaments[guild], vol.id.to_u64)
          client.create_message(payload.channel_id, "#{vol.username}##{vol.discriminator} isn't a volunteer of this tournament.")
          next
        end

        TournamentManager.tournaments[guild].volunteers.delete(vol.id.to_u64)
        volunteers << "**#{vol.username}##{vol.discriminator}**"
      end
      TournamentManager.save(TournamentManager.tournaments[guild])

      client.create_message(payload.channel_id, "Successfully removed #{volunteers.join(", ")} from the list of volunteers.") unless volunteers.empty?
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!addCommentator"),
        GuildChecker.new,
        MentionChecker.new(1),
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Creator)
      }
    )]
    def add_commentator(payload, ctx)
      guild = ctx[GuildChecker::Result].id

      commentators = Array(String).new

      payload.mentions.each do |com|
        if ctx[PermissionChecker].commentator?(TournamentManager.tournaments[guild], com.id.to_u64)
          client.create_message(payload.channel_id, "#{com.username}##{com.discriminator} is already a staff member of this tournament.")
          next
        end

        TournamentManager.tournaments[guild].commentators << com.id.to_u64
        commentators << "**#{com.username}##{com.discriminator}**"
      end
      TournamentManager.save(TournamentManager.tournaments[guild])

      client.create_message(payload.channel_id, "Successfully added #{commentators.join(", ")} to the list of commentators.") unless commentators.empty?
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!removeCommentator"),
        GuildChecker.new,
        MentionChecker.new(1),
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Creator)
      }
    )]
    def remove_commentator(payload, ctx)
      guild = ctx[GuildChecker::Result].id

      commentators = Array(String).new

      payload.mentions.each do |com|
        unless ctx[PermissionChecker].commentator?(TournamentManager.tournaments[guild], com.id.to_u64)
          client.create_message(payload.channel_id, "#{com.username}##{com.discriminator} isn't a commentator of this tournament.")
          next
        end

        TournamentManager.tournaments[guild].commentators.delete(com.id.to_u64)
        commentators << "**#{com.username}##{com.discriminator}**"
      end
      TournamentManager.save(TournamentManager.tournaments[guild])

      client.create_message(payload.channel_id, "Successfully removed #{commentators.join(", ")} from the list of commentators.") unless commentators.empty?
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!join"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::None)
      }
    )]
    def join(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      if TournamentManager.tournaments[guild].started
        client.create_message(payload.channel_id, "The tournament *#{TournamentManager.tournaments[guild].name}* has already started, so you can't join it anymore.")
        return
      end
      TournamentManager.tournaments[guild].participants << payload.author.id.to_u64

      TournamentManager.save(TournamentManager.tournaments[guild])
      client.create_message(payload.channel_id, "<@#{payload.author.id.to_u64}>, you have successfully been entered into the tournament **#{TournamentManager.tournaments[guild].name}**!")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!leave"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Participant)
      }
    )]
    def leave(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      if TournamentManager.tournaments[guild].started
        client.create_message(payload.channel_id, "The tournament *#{TournamentManager.tournaments[guild].name}* has already started, so you can't leave it anymore.")
        return
      end
      TournamentManager.tournaments[guild].participants.delete(payload.author.id.to_u64)
      TournamentManager.tournaments[guild].clean_matches(payload.author.id.to_u64)

      TournamentManager.save(TournamentManager.tournaments[guild])
      client.create_message(payload.channel_id, "<@#{payload.author.id.to_u64}>, you have successfully dropped out of the tournament **#{TournamentManager.tournaments[guild].name}**!")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!remove"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Host)
      }
    )]
    def remove(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      user = if payload.mentions.empty?
        begin
          _, id = payload.content.split(" ", remove_empty: true)
          TournamentBot.bot.cache.resolve_user(id.to_u64)
        rescue e : Exception
          client.create_message(payload.channel_id, "Please provide a valid user ID.")
          return
        end
      else
        payload.mentions.first
      end
      unless TournamentManager.tournaments[guild].participants.includes?(user.id.to_u64)
        client.create_message(payload.channel_id, "#{user.username}##{user.discriminator} isn't part of the tournament **#{TournamentManager.tournaments[guild].name}**.")
        return
      end
      TournamentManager.tournaments[guild].participants.delete(user.id.to_u64)
      TournamentManager.tournaments[guild].clean_matches(user.id.to_u64)

      TournamentManager.save(TournamentManager.tournaments[guild])
      client.create_message(payload.channel_id, "<@#{user.id.to_u64}> has successfully been removed from the tournament **#{TournamentManager.tournaments[guild].name}**.")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!setBracket"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Host),
        ArgumentChecker.new(min_args: 1)
      }
    )]
    def set_bracket(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      bracket = ctx[ArgumentChecker::Result].args.join(" ")

      TournamentManager.tournaments[guild].bracket = "See the bracket at #{bracket}."
      TournamentManager.save(TournamentManager.tournaments[guild])

      client.create_message(payload.channel_id, "The bracket for the tournament **#{TournamentManager.tournaments[guild].name}** has been set to *#{bracket}*.")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!setGame"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Host),
        ArgumentChecker.new(min_args: 1)
      }
    )]
    def set_game(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      game = ctx[ArgumentChecker::Result].args.join(" ")

      TournamentManager.tournaments[guild].game = game
      TournamentManager.save(TournamentManager.tournaments[guild])

      client.create_message(payload.channel_id, "The game for the tournament **#{TournamentManager.tournaments[guild].name}** has been set to *#{game}*.")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!setName"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Creator),
        ArgumentChecker.new(min_args: 1)
      }
    )]
    def set_name(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      name = ctx[ArgumentChecker::Result].args.join(" ")

      TournamentManager.tournaments[guild].name = name
      TournamentManager.save(TournamentManager.tournaments[guild])

      client.create_message(payload.channel_id, "The name for the tournament has been changed to *#{name}*.")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!start"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Host)
      }
    )]
    def start(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      tournament = TournamentManager.tournaments[guild]

      if tournament.started
        client.create_message(payload.channel_id, "The tournament *#{tournament.name}* has already started.")
        return
      end

      tournament.started = true

      staff = (tournament.hosts + tournament.volunteers).uniq
      staff.each do |s|
        TournamentBot.bot.client.add_guild_member_role(guild, s, tournament.draft_role)
      end

      client.create_message(payload.channel_id, "The tournament *#{tournament.name}* has been started! All staff members have received the draft pick role.")
      TournamentManager.save(tournament)
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!setMaps"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Host)
      }
    )]
    def set_maps(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      # None should always be an available option, for the disrespect bans.
      maps = payload.content[9..-1].split(", ") << "None"
      TournamentManager.tournaments[guild].maps = maps

      TournamentManager.save(TournamentManager.tournaments[guild])

      client.create_message(payload.channel_id, "Set the tournament's map pool to *#{maps.join("*, *")}*.")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!maps"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments)
      }
    )]
    def maps(payload, ctx)
      guild = ctx[GuildChecker::Result].id

      if TournamentManager.tournaments[guild].maps.empty?
        client.create_message(payload.channel_id, "There are no maps set for this tournament.")
      else
        client.create_message(payload.channel_id, "", TournamentManager.tournaments[guild].map_embed)
      end
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!setBans"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Host),
        ArgumentChecker.new(1)
      }
    )]
    def set_bans(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      bpp = ctx[ArgumentChecker::Result].args.first.to_i
      TournamentManager.tournaments[guild].bans_per_player = bpp
      TournamentManager.save(TournamentManager.tournaments[guild])
      client.create_message(payload.channel_id, "The tournament's bans per player have been set to #{bpp}.")
    rescue e : ArgumentError
      client.create_message(payload.channel_id, "Please provide an integer.")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!setPicks"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Host),
        ArgumentChecker.new(1)
      }
    )]
    def set_picks(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      ppp = ctx[ArgumentChecker::Result].args.first.to_i
      TournamentManager.tournaments[guild].picks_per_player = ppp
      TournamentManager.save(TournamentManager.tournaments[guild])
      client.create_message(payload.channel_id, "The tournament's picks per player have been set to #{ppp}.")
    rescue e : ArgumentError
      client.create_message(payload.channel_id, "Please provide an integer.")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!setRandomMaps"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Host),
        ArgumentChecker.new(1)
      }
    )]
    def set_random_maps(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      rm = ctx[ArgumentChecker::Result].args.first.to_i
      TournamentManager.tournaments[guild].random_maps = rm
      TournamentManager.save(TournamentManager.tournaments[guild])
      client.create_message(payload.channel_id, "The tournament's random maps per match have been set to #{rm}.")
    rescue e : ArgumentError
      client.create_message(payload.channel_id, "Please provide an integer.")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!addDefaultBan"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Host),
        ArgumentChecker.new(1)
      }
    )]
    def add_default_ban(payload, ctx)
      guild      = ctx[GuildChecker::Result].id
      tournament = TournamentManager.tournaments[guild]
      map        = ctx[ArgumentChecker::Result].args.join(" ")
      map        = tournament.select_map(map)
      unless map
        client.create_message(payload.channel_id, "This map wasn't found in the list of available maps. Please try again.")
        return
      end
      if tournament.default_bans.includes?(map)
        client.create_message(payload.channel_id, "This map is already banned by default.")
        return
      end

      tournament.default_bans << map
      TournamentManager.save(tournament)
      client.create_message(payload.channel_id, "Successfully added `#{map}` to the list of default-banned maps.")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!removeDefaultBan"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Host),
        ArgumentChecker.new(1)
      }
    )]
    def remove_default_ban(payload, ctx)
      guild      = ctx[GuildChecker::Result].id
      tournament = TournamentManager.tournaments[guild]
      map        = ctx[ArgumentChecker::Result].args.join(" ")
      map        = tournament.select_map(map)
      unless map
        client.create_message(payload.channel_id, "This map wasn't found in the list of available maps. Please try again.")
        return
      end
      unless tournament.default_bans.includes?(map)
        client.create_message(payload.channel_id, "This map isn't banned by default.")
        return
      end

      tournament.default_bans.delete(map)
      TournamentManager.save(tournament)
      client.create_message(payload.channel_id, "Successfully removed `#{map}` from the list of default-banned maps.")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!defaultBans"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments),
      }
    )]
    def default_bans(payload, ctx)
      client.create_message(payload.channel_id, "The maps `#{TournamentManager.tournaments[ctx[GuildChecker::Result].id].default_bans.join("`, `")}` are banned by default.")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!updateDraftRole"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments)
      }
    )]
    def update_draft_role(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      TournamentManager.tournaments[guild].validate_draft_role

      TournamentManager.save(TournamentManager.tournaments[guild])
      client.create_message(payload.channel_id, "The draft pick role has been validated and - if necessary - recreated.")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!allowPastPicks"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Host),
        ArgumentChecker.new(1)
      }
    )]
    def allow_past_picks(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      allowed = ctx[ArgumentChecker::Result].args.first == "true"
      TournamentManager.tournaments[guild].allow_past_picks = allowed

      TournamentManager.save(TournamentManager.tournaments[guild])
      client.create_message(payload.channel_id, "Picking maps that the player has picked in previous matches is #{allowed ? "now allowed" : "no longer allowed"}.")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!clearMatchHistory"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Host)
      }
    )]
    def clear_match_history(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      TournamentManager.tournaments[guild].match_history = MatchHistory.new(Array(Match).new)
      TournamentManager.save(TournamentManager.tournaments[guild])

      client.create_message(payload.channel_id, "The match history has been cleared successfully.")
    end

    private def load_tournaments
      Dir.open("./tournament-files") do |dir|

        dir.each do |name|
          next if name =~ /^\.\.?$/
          guild_id = name.split(".").first
          TournamentManager.tournaments[guild_id.to_u64] = Tournament.from_yaml(File.read("./tournament-files/#{name}"))
          TournamentManager.tournaments[guild_id.to_u64].update_next
        end
      end

      TournamentManager.tournaments.each_value do |tournament|
        tournament.matches.each do |match|
          match.schedule
        end
      end
    end
  end
end
