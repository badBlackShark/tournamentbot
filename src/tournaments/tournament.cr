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
  property matches          : Array(Match)
  property next_match       : String
  property match_id_counter : Int32


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
    @matches          = Array(Match).new
    @next_match       = ""
    @match_id_counter = 0
  end

  def to_embed(cache : Discord::Cache?) : Discord::Embed
    return Discord::Embed.new(title: "Can't create embed without cache.") if cache.nil?

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
    else
      embed.footer = Discord::EmbedFooter.new(text: "This tournament hasn't started yet. Join it by typing \"!join\"!")
      embed.colour = 0x00FF00
    end

    embed.fields = fields
    embed
  end

  def match_list_embed(cache : Discord::Cache?) : Discord::Embed
    return Discord::Embed.new(title: "Can't create embed without cache.") if cache.nil?

    embed   = Discord::Embed.new
    matches = @matches
    field   = ""
    if matches.empty?
      field = "There's currently no match scheduled."
    else
      field = matches.map { |match| "**##{match.id}**: #{match.participants.map { |p| "<@#{p}>" }.join(" vs ")}\n#{Utility.format_time(match.time)}\n\n" }.join
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
    to_delete = Array(Match).new
    @matches.each do |match|
      if match.participants.includes?(participant)
        to_delete << match
      end
    end

    @matches -= to_delete
  end

  def start_next
    @next_match = @matches[1]? ? matches[1].to_s : "*There's currently no match scheduled.*"
    @matches.delete(@matches[0]?)
  end

  def update_next
    @next_match = @matches[0]? ? matches[0].to_s : "*There's currently no match scheduled.*"
  end

  def add_match(participants : Array(UInt64), time : Time)
    @matches << Match.new(participants, time, @match_id_counter += 1)
    @matches = @matches.sort_by { |match| match.time }

    update_next
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
