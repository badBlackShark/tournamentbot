require "levenshtein"

class TournamentBot::Tournament
  include Random::Secure
  include YAML::Serializable

  property name             : String
  property guild            : UInt64
  property game             : String
  property creator          : UInt64
  property hosts            : Array(UInt64)
  property volunteers       : Array(UInt64)
  property commentators     : Array(UInt64)
  property participants     : Array(UInt64)
  property bracket          : String
  property started          : Bool
  property maps             : Array(String)
  property default_bans     : Array(String)
  property matches          : Array(Match)
  property next_match       : String
  property match_id_counter : Int32
  property draft_role       : UInt64
  property match_history    : MatchHistory
  property bans_per_player  : Int32
  property picks_per_player : Int32


  def initialize(author : UInt64, guild : UInt64, name : String?)
    @name             = name.empty? ? Random::Secure.hex(3) : name
    @guild            = guild
    @game             = "*No game set for this tournament yet.*"
    @creator          = author
    @hosts            = [author]
    @volunteers       = Array(UInt64).new
    @commentators     = [author]
    @participants     = Array(UInt64).new
    @bracket          = "*No bracket set for this tournament yet.*"
    @started          = false
    @maps             = Array(String).new
    @default_bans     = Array(String).new
    @matches          = Array(Match).new
    @next_match       = ""
    @match_id_counter = 0
    @match_history    = MatchHistory.new(Array(Match).new)
    @bans_per_player  = 0
    @picks_per_player = 0

    @draft_role = if draft_role = TournamentBot.bot.cache.resolve_guild(@guild).roles.find { |r| r.name == "draft" }
      draft_role.id.to_u64
    else
      TournamentBot.bot.client.create_guild_role(@guild, "draft", mentionable: true).id.to_u64
    end
  end

  def to_embed : Discord::Embed
    cache = TournamentBot.bot.cache
    embed = Discord::Embed.new

    # Needed for the nil check to work.
    volunteers   = @volunteers
    commentators = @commentators

    creator      = cache.resolve_user(@creator)
    hosts        = resolve_users(@hosts, cache)
    volunteers   = resolve_users(volunteers, cache)
    commentators = resolve_users(commentators, cache)
    participants = resolve_participants(cache)

    fields = Array(Discord::EmbedField).new
    fields << Discord::EmbedField.new(name: "Hosts", value: hosts, inline: true) if hosts
    fields << Discord::EmbedField.new(name: "Volunteers", value: volunteers, inline: true) if volunteers
    fields << Discord::EmbedField.new(name: "Commentators", value: commentators, inline: true) if commentators
    fields << Discord::EmbedField.new(name: "Participants", value: participants)

    embed.author      = Discord::EmbedAuthor.new(name: "#{creator.username} presents:", icon_url: creator.avatar_url)
    embed.title       = "__#{@name}__ (#{@game})"
    embed.description = @bracket

    if @started
      embed.footer = Discord::EmbedFooter.new(text: "This tournament has already started, you can not sign up for it any longer.")
      embed.colour = 0xFF0000

      fields << Discord::EmbedField.new(name: "Next match", value: @next_match)
      fields << Discord::EmbedField.new(name: "Bans per player", value: @bans_per_player.to_s, inline: true)
      fields << Discord::EmbedField.new(name: "Picks per player", value: @picks_per_player.to_s, inline: true)
    else
      embed.footer = Discord::EmbedFooter.new(text: "This tournament hasn't started yet. Join it by typing \"!join\"!")
      embed.colour = 0x00FF00
    end

    embed.fields = fields
    embed
  end

  def map_embed
    cache  = TournamentBot.bot.cache
    embed  = Discord::Embed.new
    fields = Array(Discord::EmbedField).new

    embed.title = "The map pool for the tournament #{@name}"

    nr_of_fields  = (@maps.size / 10.0).ceil.to_i
    field_nr      = 0
    map_nr        = 0

    @maps.each_slice(10) do |maps|
      fields << Discord::EmbedField.new(
        name: "Maps (#{field_nr += 1}/#{nr_of_fields})",
        value: maps.map { |m| "##{map_nr += 1}: #{m}" }.join("\n"),
        inline: true
      )
    end

    embed.fields = fields
    embed.colour = 0xFF00AA

    embed
  end

  def match_list_embed : Discord::Embed
    cache = TournamentBot.bot.cache
    embed   = Discord::Embed.new
    matches = @matches

    field = if matches.empty?
      "There's currently no match scheduled."
    else
      matches.map { |match| "**##{match.id}**: #{match.participants.map { |p| "<@#{p}>" }.join(" vs ")}\n#{Utility.format_time(match.time)}\n\n" }.join
    end

    embed.title       = "All matches currently scheduled for __#{@name}__"
    embed.description = "Click [here](https://time.is/UTC) to see what time it is in UTC right now."
    embed.fields      = [Discord::EmbedField.new(name: "Match list", value: field)]
    embed.colour      = 0xFF00AA
    embed.footer      = Discord::EmbedFooter.new(text: "Please be online 30 minutes before your match starts, and remember that all times are in UTC!")

    embed
  end

  # Clears all the matches from a participant that left the tournament.
  def clean_matches(participant : UInt64)
    @matches.dup.each do |match|
      if match.participants.includes?(participant)
        @matches.delete(match)
      end
    end
  end

  def start_next
    matches[0].start_draft(@guild, @draft_role) if matches[0]
    @next_match = if @matches[1]?
      matches[1].to_s
    else
      "*There's currently no match scheduled.*"
    end
  end

  def update_next
    @next_match = @matches[0]? ? matches[0].to_s : "*There's currently no match scheduled.*"
  end

  def add_match(participants : Array(UInt64), time : Time)
    @matches << Match.new(participants, time, @match_id_counter += 1, self)
    @matches = @matches.sort_by { |match| match.time }

    update_next
  end

  def validate_draft_role
    unless TournamentBot.bot.cache.guild_roles(@guild).find { |r| r == @draft_role }
      @draft_role = TournamentBot.bot.client.create_guild_role(@guild, "draft", mentionable: true).id.to_u64
    end
  end

  def select_map(name : String)
    res = Utility.fuzzy_match(name, @maps)
    return res.empty? ? nil : res
  end

  def random_map
    @maps.sample
  end

  private def resolve_users(users : Array(UInt64), cache : Discord::Cache) : String?
    return nil if users.empty?

    users.map { |u| "• #{cache.resolve_user(u).username}##{cache.resolve_user(u).discriminator}\n" }.join
  end

  # Different method because participants need to be numbered for seeding purposes.
  private def resolve_participants(cache : Discord::Cache) : String
    participants = @participants
    return "*No one is participating in this tournament yet.*" if participants.empty?

    n = 0
    participants.map { |u| "**#{n += 1}**: #{cache.resolve_user(u).username}##{cache.resolve_user(u).discriminator}\n" }.join
  end
end
