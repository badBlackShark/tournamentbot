require "./tournament_creator"

module TournamentBot::TournamentManager
  @[Discord::Plugin::Options()]
  class TournamentBot::MatchManager
    include Discord::Plugin

    def initialize
      @parser = Time::Format.new("%d.%m.%y %R", Time::Location.fixed("UTC", 0))
    end

      @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!createMatch"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Host),
        MentionChecker.new(2),
        ArgumentChecker.new(3)
      }
    )]
    def create_match(payload, ctx)
      guild = ctx[GuildChecker::Result].id
      args  = ctx[ArgumentChecker::Result].args

      payload.mentions.each do |participant|
        unless TournamentManager.tournaments[guild].participants.includes?(participant.id.to_u64)
          client.create_message(payload.channel_id, "All mentioned people need to be participants in the tournament.")
          return
        end
      end

      time_raw = args.reject { |e| e =~ /<@\d+>/ }.join(" ")
      time = Time.new
      begin
        time = @parser.parse(time_raw)
      rescue e : Time::Format::Error
        client.create_message(payload.channel_id, "Please provide the time in the required format (dd.MM.yy hh:mm).")
        return
      end

      TournamentManager.tournaments[guild].add_match(payload.mentions.map { |e| e.id.to_u64 }, time)
      client.create_message(payload.channel_id, "Added match between **#{payload.mentions.map { |e| e.username }.join("**, **")}** on *#{Utility.format_time(time)}*.")
      TournamentManager.save(TournamentManager.tournaments[guild])
    end

    @[Discord::Handler(
      event: :message_create,
      middleware: {
        Command.new("!deleteMatch"),
        GuildChecker.new,
        TournamentChecker.new(TournamentManager.tournaments),
        PermissionChecker.new(TournamentManager.tournaments, Permission::Volunteer),
        ArgumentChecker.new(1)
      }
    )]
    def delete_match(payload, ctx)
      id = ctx[ArgumentChecker::Result].args.first.to_i
      guild = ctx[GuildChecker::Result].id
      match = TournamentManager.tournaments[guild].matches.find { |match| match.id == id }
      if match
        TournamentManager.tournaments[guild].matches.delete(match)
        client.create_message(payload.channel_id, "The match #{match.participants.map { |e| "<@#{e}>" }.join(" vs ")}, which was scheduled for #{Utility.format_time(match.time)}, has been deleted.")
        TournamentManager.tournaments[guild].update_next
        TournamentManager.save(TournamentManager.tournaments[guild])
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
        TournamentChecker.new(TournamentManager.tournaments),
      }
    )]
    def match_list(payload, ctx)
      client.create_message(payload.channel_id, "", TournamentManager.tournaments[ctx[GuildChecker::Result].id].match_list_embed)
    end
  end
end
