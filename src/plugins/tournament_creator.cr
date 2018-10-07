require "yaml"

module TournamentBot::TournamentCreator
  @[Discord::Plugin::Options()]
  class TournamentBot::TournamentCommands
    include Discord::Plugin

    property tournaments : Hash(UInt64, Tournament)

    def initialize
      @tournaments = Hash(UInt64, Tournament).new
      @parser      = Time::Format.new("%d.%m.%y %I:%M%p", Time::Location.fixed("UTC", 0))
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

      if @tournaments[guild]?
        client.create_message(payload.channel_id, "There is already a tournament being ran on this server. More than that is currently not supported.")
        return
      end

      tournament = Tournament.new(author, guild, name)
      embed = tournament.to_embed

      @tournaments[guild] = tournament

      save(tournament)

      client.create_message(payload.channel_id,"", embed)
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!tournament"),
        GuildChecker.new,
        TournamentChecker.new(@tournaments)
      }
    )]
    def tournament(payload, ctx)
      guild = ctx[GuildChecker::Result].id

      client.create_message(payload.channel_id,"", @tournaments[guild].to_embed)
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!delete"),
        GuildChecker.new,
        TournamentChecker.new(@tournaments),
        PermissionChecker.new(@tournaments, Permission::Creator)
      }
    )]
    def delete(payload, ctx)
      guild = ctx[GuildChecker::Result].id

      name = @tournaments[guild].name
      File.delete("./tournament-files/#{guild}.yml")
      @tournaments.delete(guild)

      client.create_message(payload.channel_id, "The tournament *#{name}* was successfully deleted.")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!addHost"),
        GuildChecker.new,
        MentionChecker.new(1),
        TournamentChecker.new(@tournaments),
        PermissionChecker.new(@tournaments, Permission::Creator)
      }
    )]
    def add_host(payload, ctx)
      guild = ctx[GuildChecker::Result].id

      hosts = Array(String).new

      payload.mentions.each do |host|
        if ctx[PermissionChecker].host?(@tournaments[guild], host.id.to_u64)
          client.create_message(payload.channel_id, "#{host.username}##{host.discriminator} is already a host of this tournament.")
          next
        end

        @tournaments[guild].hosts << host.id.to_u64
        hosts << "**#{host.username}##{host.discriminator}**"
      end
      save(@tournaments[guild])

      client.create_message(payload.channel_id, "Successfully added #{hosts.join(", ")} to the list of hosts.") unless hosts.empty?
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!removeHost"),
        GuildChecker.new,
        MentionChecker.new(1),
        TournamentChecker.new(@tournaments),
        PermissionChecker.new(@tournaments, Permission::Creator)
      }
    )]
    def remove_host(payload, ctx)
      guild = ctx[GuildChecker::Result].id

      hosts = Array(String).new

      payload.mentions.each do |host|
        unless ctx[PermissionChecker].creator?(@tournaments[guild], host.id.to_u64)
          client.create_message(payload.channel_id, "#{host.username}##{host.discriminator} isn't a host of this tournament.")
          next
        end

        if @tournaments[guild].creator == host.id.to_u64
          client.create_message(payload.channel_id, "You can't remove yourself from the team of hosts.")
          next
        end

        @tournaments[guild].hosts.delete(host.id.to_u64)
        hosts << "**#{host.username}##{host.discriminator}**"
      end
      save(@tournaments[guild])

      client.create_message(payload.channel_id, "Successfully removed #{hosts.join(", ")} from the list of hosts.") unless hosts.empty?
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!addVolunteer"),
        GuildChecker.new,
        MentionChecker.new(1),
        TournamentChecker.new(@tournaments),
        PermissionChecker.new(@tournaments, Permission::Creator)
      }
    )]
    def add_volunteer(payload, ctx)
      guild = ctx[GuildChecker::Result].id

      volunteers = Array(String).new

      payload.mentions.each do |vol|
        if ctx[PermissionChecker].volunteer?(@tournaments[guild], vol.id.to_u64)
          client.create_message(payload.channel_id, "#{vol.username}##{vol.discriminator} is already a staff member of this tournament.")
          next
        end

        @tournaments[guild].volunteers << vol.id.to_u64
        volunteers << "**#{vol.username}##{vol.discriminator}**"
      end
      save(@tournaments[guild])

      client.create_message(payload.channel_id, "Successfully added #{volunteers.join(", ")} to the list of volunteers.") unless volunteers.empty?
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!removeVolunteer"),
        GuildChecker.new,
        MentionChecker.new(1),
        TournamentChecker.new(@tournaments),
        PermissionChecker.new(@tournaments, Permission::Creator)
      }
    )]
    def remove_volunteer(payload, ctx)
      guild = ctx[GuildChecker::Result].id

      volunteers = Array(String).new

      payload.mentions.each do |vol|
        unless ctx[PermissionChecker].volunteer?(@tournaments[guild], vol.id.to_u64)
          client.create_message(payload.channel_id, "#{vol.username}##{vol.discriminator} isn't a volunteer of this tournament.")
          next
        end

        @tournaments[guild].volunteers.delete(vol.id.to_u64)
        volunteers << "**#{vol.username}##{vol.discriminator}**"
      end
      save(@tournaments[guild])

      client.create_message(payload.channel_id, "Successfully removed #{volunteers.join(", ")} from the list of volunteers.") unless volunteers.empty?
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!addCommentator"),
        GuildChecker.new,
        MentionChecker.new(1),
        TournamentChecker.new(@tournaments),
        PermissionChecker.new(@tournaments, Permission::Creator)
      }
    )]
    def add_commentator(payload, ctx)
      guild = ctx[GuildChecker::Result].id

      commentators = Array(String).new

      payload.mentions.each do |com|
        if ctx[PermissionChecker].commentator?(@tournaments[guild], com.id.to_u64)
          client.create_message(payload.channel_id, "#{com.username}##{com.discriminator} is already a staff member of this tournament.")
          next
        end

        @tournaments[guild].commentators << com.id.to_u64
        commentators << "**#{com.username}##{com.discriminator}**"
      end
      save(@tournaments[guild])

      client.create_message(payload.channel_id, "Successfully added #{commentators.join(", ")} to the list of commentators.") unless commentators.empty?
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!removeCommentator"),
        GuildChecker.new,
        MentionChecker.new(1),
        TournamentChecker.new(@tournaments),
        PermissionChecker.new(@tournaments, Permission::Creator)
      }
    )]
    def remove_commentator(payload, ctx)
      guild = ctx[GuildChecker::Result].id

      commentators = Array(String).new

      payload.mentions.each do |com|
        unless ctx[PermissionChecker].commentator?(@tournaments[guild], com.id.to_u64)
          client.create_message(payload.channel_id, "#{com.username}##{com.discriminator} isn't a commentator of this tournament.")
          next
        end

        @tournaments[guild].commentators.delete(com.id.to_u64)
        commentators << "**#{com.username}##{com.discriminator}**"
      end
      save(@tournaments[guild])

      client.create_message(payload.channel_id, "Successfully removed #{commentators.join(", ")} from the list of commentators.") unless commentators.empty?
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!join"),
        GuildChecker.new,
        TournamentChecker.new(@tournaments),
        PermissionChecker.new(@tournaments, Permission::None)
      }
    )]
    def join(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      if @tournaments[guild].started
        client.create_message(payload.channel_id, "The tournament *#{@tournaments[guild].name}* has already started, so you can't join it anymore.")
        return
      end
      @tournaments[guild].participants << payload.author.id.to_u64

      save(@tournaments[guild])
      client.create_message(payload.channel_id, "<@#{payload.author.id.to_u64}>, you have successfully been entered into the tournament **#{@tournaments[guild].name}**!")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!leave"),
        GuildChecker.new,
        TournamentChecker.new(@tournaments),
        PermissionChecker.new(@tournaments, Permission::Participant)
      }
    )]
    def leave(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      if @tournaments[guild].started
        client.create_message(payload.channel_id, "The tournament *#{@tournaments[guild].name}* has already started, so you can't leave it anymore.")
        return
      end
      @tournaments[guild].participants.delete(payload.author.id.to_u64)
      @tournaments[guild].clean_matches(payload.author.id.to_u64)

      save(@tournaments[guild])
      client.create_message(payload.channel_id, "<@#{payload.author.id.to_u64}>, you have successfully dropped out of the tournament **#{@tournaments[guild].name}**!")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!remove"),
        GuildChecker.new,
        TournamentChecker.new(@tournaments),
        PermissionChecker.new(@tournaments, Permission::Host)
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
      unless @tournaments[guild].participants.includes?(user.id.to_u64)
        client.create_message(payload.channel_id, "#{user.username}##{user.discriminator} isn't part of the tournament **#{@tournaments[guild].name}**.")
        return
      end
      @tournaments[guild].participants.delete(user.id.to_u64)
      @tournaments[guild].clean_matches(user.id.to_u64)

      save(@tournaments[guild])
      client.create_message(payload.channel_id, "<@#{user.id.to_u64}> has successfully been removed from the tournament **#{@tournaments[guild].name}**.")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!setBracket"),
        GuildChecker.new,
        TournamentChecker.new(@tournaments),
        PermissionChecker.new(@tournaments, Permission::Host),
        ArgumentChecker.new(min_args: 1)
      }
    )]
    def set_bracket(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      bracket = ctx[ArgumentChecker::Result].args.join(" ")

      @tournaments[guild].bracket = "See the bracket at #{bracket}."
      save(@tournaments[guild])

      client.create_message(payload.channel_id, "The bracket for the tournament **#{@tournaments[guild].name}** has been set to *#{bracket}*.")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!setGame"),
        GuildChecker.new,
        TournamentChecker.new(@tournaments),
        PermissionChecker.new(@tournaments, Permission::Host),
        ArgumentChecker.new(min_args: 1)
      }
    )]
    def set_game(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      game = ctx[ArgumentChecker::Result].args.join(" ")

      @tournaments[guild].game = game
      save(@tournaments[guild])

      client.create_message(payload.channel_id, "The game for the tournament **#{@tournaments[guild].name}** has been set to *#{game}*.")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!setName"),
        GuildChecker.new,
        TournamentChecker.new(@tournaments),
        PermissionChecker.new(@tournaments, Permission::Creator),
        ArgumentChecker.new(min_args: 1)
      }
    )]
    def set_name(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      name = ctx[ArgumentChecker::Result].args.join(" ")

      @tournaments[guild].name = name
      save(@tournaments[guild])

      client.create_message(payload.channel_id, "The name for the tournament has been changed to *#{name}*.")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!start"),
        GuildChecker.new,
        TournamentChecker.new(@tournaments),
        PermissionChecker.new(@tournaments, Permission::Host)
      }
    )]
    def start(payload, ctx)
      guild = ctx[GuildChecker::Result].id

      if @tournaments[guild].started
        client.create_message(payload.channel_id, "The tournament *#{@tournaments[guild].name}* has already started.")
        return
      end

      @tournaments[guild].started = true
      client.create_message(payload.channel_id, "The tournament *#{@tournaments[guild].name}* has been started!")
      save(@tournaments[guild])
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!createMatch"),
        GuildChecker.new,
        TournamentChecker.new(@tournaments),
        PermissionChecker.new(@tournaments, Permission::Host),
        MentionChecker.new(2),
        ArgumentChecker.new(3)
      }
    )]
    def create_match(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      args  = ctx[ArgumentChecker::Result].args

      payload.mentions.each do |participant|
        unless @tournaments[guild].participants.includes?(participant.id.to_u64)
          client.create_message(payload.channel_id, "All mentioned people need to be participants in the tournament.")
          return
        end
      end

      time_raw = args.reject { |e| e =~ /<@\d+>/ }.join(" ")
      time = Time.new
      begin
        time = @parser.parse(time_raw)
      rescue e : Time::Format::Error
        client.create_message(payload.channel_id, "Please provide the time in the required format (DD.MM.YY HH:MMam/pm).")
        return
      end

      @tournaments[guild].add_match(payload.mentions.map { |e| e.id.to_u64 }, time)
      client.create_message(payload.channel_id, "Added match between **#{payload.mentions.map { |e| e.username }.join("**, **")}** on *#{Utility.format_time(time)}*.")
      save(@tournaments[guild])
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!nextMatch"),
        GuildChecker.new,
        TournamentChecker.new(@tournaments),
        PermissionChecker.new(@tournaments, Permission::Volunteer),
      }
    )]
    def next_match(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      match = @tournaments[guild].matches[0]?

      if match
        @tournaments[guild].start_next
        client.create_message(payload.channel_id, "#{match.participants.map { |e| "<@#{e}>" }.join(", ")}, your match, which was scheduled for #{Utility.format_time(match.time)}, is starting now!")
        save(@tournaments[guild])
      else
        client.create_message(payload.channel_id, "There are currently no more scheduled matches.")
      end
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!deleteMatch"),
        GuildChecker.new,
        TournamentChecker.new(@tournaments),
        PermissionChecker.new(@tournaments, Permission::Volunteer),
        ArgumentChecker.new(1)
      }
    )]
    def delete_match(payload, ctx)
      id = ctx[ArgumentChecker::Result].args.first.to_i
      guild = ctx[GuildChecker::Result].id
      match = @tournaments[guild].matches.find { |match| match.id == id }
      if match
        @tournaments[guild].matches.delete(match)
        client.create_message(payload.channel_id, "The match #{match.participants.map { |e| "<@#{e}>" }.join(" vs ")}, which was scheduled for #{Utility.format_time(match.time)}, has been deleted.")
        @tournaments[guild].update_next
        save(@tournaments[guild])
      else
        client.create_message(payload.channel_id, "No match with ID #{id} exists.")
      end
    rescue e : ArgumentError
      client.create_message(payload.channel_id, "Please provide an Integer ID.")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!matchList"),
        GuildChecker.new,
        TournamentChecker.new(@tournaments),
      }
    )]
    def match_list(payload, ctx)
      client.create_message(payload.channel_id, "", @tournaments[ctx[GuildChecker::Result].id].match_list_embed)
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!setMaps"),
        GuildChecker.new,
        TournamentChecker.new(@tournaments),
        PermissionChecker.new(@tournaments, Permission::Host)
      }
    )]
    def set_maps(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      # None should always be an available option, for the disrespect bans.
      maps = payload.content[9..-1].split(", ") << "None"
      @tournaments[guild].maps = maps

      save(@tournaments[guild])

      client.create_message(payload.channel_id, "Set the tournament's map pool to *#{maps.join("*, *")}*.")
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!maps"),
        GuildChecker.new,
        TournamentChecker.new(@tournaments)
      }
    )]
    def maps(payload, ctx)
      guild = ctx[GuildChecker::Result].id

      if @tournaments[guild].maps.empty?
        client.create_message(payload.channel_id, "There are no maps set for this tournament.")
      else
        client.create_message(payload.channel_id, "", @tournaments[guild].map_embed)
      end
    end

    private def load_tournaments
      Dir.open("./tournament-files") do |dir|

        dir.each do |name|
          next if name =~ /^\.\.?$/
          guild_id = name.split(".").first
          @tournaments[guild_id.to_u64] = Tournament.from_yaml(File.read("./tournament-files/#{name}"))
          @tournaments[guild_id.to_u64].update_next
        end
      end

      @tournaments.each_value do |tournament|
        tournament.matches.each do |match|
          match.schedule
        end
      end
    end

    private def save(tournament : Tournament)
      File.open("./tournament-files/#{tournament.guild}.yml", "w") { |f| tournament.to_yaml(f) }
    end
  end
end
