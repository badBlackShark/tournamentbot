module TournamentBot::TournamentManager
  @[Discord::Plugin::Options()]
  class DraftManager
    include Discord::Plugin

    # Channel => DraftPick
    getter drafts = Hash(UInt64, Draft).new

    def add_draft(channel : UInt64, draft : Draft)
      @drafts[channel] = draft
    end

    def draft_complete(channel : UInt64)
      @drafts.delete(channel)
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!startNext"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Volunteer),
      }
    )]
    def start_next(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      tournament = TournamentManager.tournaments[guild]
      match = tournament.matches[0]?

      if match
        tournament.start_next
        @drafts[match.channel] = Draft.new(match, tournament.bans_per_player, tournament.picks_per_player)
        client.create_message(payload.channel_id, "#{match.participants.map { |e| "<@#{e}>" }.join(", ")}, your match, which was scheduled for #{Utility.format_time(match.time)}, is starting now!")
        tournament.match_history.add(match)
        tournament.matches.delete(match)
        TournamentManager.save(tournament)
      else
        client.create_message(payload.channel_id, "There are currently no more scheduled matches.")
      end
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!ban"),
        GuildChecker.new,
        DraftChecker.new(@drafts),
        TurnChecker.new(@drafts),
        ArgumentChecker.new(1),
        BanChecker.new(@drafts, false)
      }
    )]
    def ban(payload, ctx)
      draft = @drafts[payload.channel_id]
      map = ctx[ArgumentChecker::Result].args.join(" ")
      map = draft.match.tournament.select_map(map)
      unless map
        client.create_message(payload.channel_id, "This map wasn't found in the list of available maps. Please try again.")
        return
      end
      if draft.match.bans.includes?(map)
        client.create_message(payload.channel_id, "The map `#{map}` is already banned.")
        return
      end
      if !draft.allow_defaults && draft.match.tournament.default_bans.includes?(map)
        client.create_message(payload.channel_id, "The map `#{map}` is banned by default. You can vote to allow it by calling `!allow`.")
        return
      end
      draft.match.bans << map
      draft.bans_left -= 1
      draft.next_turn

      client.create_message(payload.channel_id, "You successfully banned `#{map}`!")
      stage_check(draft)
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!pick"),
        GuildChecker.new,
        DraftChecker.new(@drafts),
        TurnChecker.new(@drafts),
        ArgumentChecker.new(1),
        BanChecker.new(@drafts, true)
      }
    )]
    def pick(payload, ctx)
      draft = @drafts[payload.channel_id]
      map = ctx[ArgumentChecker::Result].args.join(" ")
      map = draft.match.tournament.select_map(map)
      unless map
        client.create_message(payload.channel_id, "This map wasn't found in the list of available maps. Please try again.")
        return
      end
      if draft.match.bans.includes?(map)
        client.create_message(payload.channel_id, "The map `#{map}` is banned, and thus can't be picked.")
        return
      end
      if draft.match.picked?(map)
        client.create_message(payload.channel_id, "The map `#{map}` has already been picked.")
        return
      end
      if !draft.allow_defaults && draft.match.tournament.default_bans.includes?(map)
        client.create_message(payload.channel_id, "The map `#{map}` is banned by default. You can vote to allow it by calling `!allow`.")
        return
      end
      draft.match.picks[payload.author.id.to_u64] << map
      draft.picks_left -= 1
      draft.next_turn

      client.create_message(payload.channel_id, "You successfully picked `#{map}`!")
      stage_check(draft)
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!allow"),
        GuildChecker.new,
        DraftChecker.new(@drafts)
      }
    )]
    def allow(payload, ctx)
      draft = @drafts[payload.channel_id]
      user  = payload.author.id.to_u64
      return unless draft.match.participants.includes?(user)

      if draft.allow_votes.includes?(user)
        client.create_message(payload.channel_id, "You have already voted to allow maps banned by default.")
        return
      end

      draft.allow_votes << user
      client.create_message(payload.channel_id, "You have successfully voted to allow maps banned by default.")

      if draft.enough_votes?
        draft.allow_defaults = true
        client.create_message(payload.channel_id, "Everyone has voted to allow maps banned by default. The maps `#{draft.match.tournament.default_bans.join("`, `")}` may now be picked.")
      end
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!undo"),
        GuildChecker.new,
        DraftChecker.new(@drafts),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Volunteer)
      }
    )]
    def undo(payload, ctx)
      draft = @drafts[payload.channel_id]

      # if the pick phase hasn't started yet
      if draft.picks_left == draft.match.tournament.picks_per_player * draft.match.participants.size
        if draft.match.bans.empty?
          client.create_message(payload.channel_id, "No maps have been banned yet.")
          return
        end
        map = draft.match.bans.delete_at(-1)
        draft.bans_left += 1
        draft.turn = (draft.turn - 1) % draft.match.participants.size
        client.create_message(payload.channel_id, "The map `#{map}` is no longer banned. It is now <@#{draft.match.participants[draft.turn]}>'s turn again.")
      else
        map = draft.match.picks.values.delete_at(-1)
        draft.picks_left += 1
        draft.turn = (draft.turn - 1) % draft.match.participants.size
        client.create_message(payload.channel_id, "The map `#{map}` is no longer picked. It is now <@#{draft.match.participants[draft.turn]}>'s turn again.")
      end
    end

    def stage_check(draft : Draft)
      if draft.bans_left == 0 && draft.picks_left == draft.match.tournament.picks_per_player * draft.match.participants.size
        message = "This concludes the ban stage. To recap, the banned maps are `#{draft.match.bans.join("`, `")}`.\n"\
                  "<@#{draft.match.participants.first}> may now start the pick phase by typing `!pick <mapName>`."
        TournamentBot.bot.client.create_message(draft.match.channel, message)
      elsif draft.picks_left == 0
        embed = Discord::Embed.new
        bot = TournamentBot.bot.cache.resolve_user(TournamentBot.config.client_id)
        embed.author = Discord::EmbedAuthor.new(name: bot.username, icon_url: bot.avatar_url)
        embed.title  = "Draft phase recap"
        fields = Array(Discord::EmbedField).new
        fields << Discord::EmbedField.new(name: "Banned maps", value: draft.match.bans.map { |b| "• #{b}" }.join("\n"))
        value = ""
        all_picks = draft.match.picks.values
        (draft.match.tournament.picks_per_player * draft.match.participants.size).times do |i|
          i = i % draft.match.participants.size
          player = draft.match.picks.keys[i]
          p all_picks[i]
          value += "• **#{all_picks[i].delete_at(0)}**, picked by <@#{player}>\n"
        end
        fields << Discord::EmbedField.new(name: "Picked maps", value: value)
        embed.fields = fields
        embed.colour = 0xf700c5

        client.create_message(draft.match.channel, "The draft has been completed.", embed)
      end
    end
  end
end
