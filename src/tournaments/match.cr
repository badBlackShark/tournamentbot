class TournamentBot::Match
  include YAML::Serializable

  getter participants : Array(UInt64)
  getter time         : Time
  getter id           : Int32
  getter tournament   : Tournament
  # Every match will have a dedicated draft pick channel created for it.
  # This gets stored so the match can be deleted later
  property channel    : UInt64
  # Player => Maps picked
  property picks      : Hash(UInt64, Array(String))
  property bans       : Array(String)
  property played     : Bool

  def initialize(@participants : Array(UInt64), @time : Time, @id : Int32, @tournament : Tournament)
    @channel = 0
    @picks = Hash(UInt64, Array(String)).new
    @participants.each do |p|
      @picks[p] = Array(String).new
    end
    # Random maps go in here
    @picks[69] = Array(String).new
    @bans = Array(String).new
    @played = false
    schedule
  end

  def to_s
    "Match ##{@id}: #{participants.map { |e| "<@#{e}>" }.join(" vs ")} on #{Utility.format_time(@time)}"
  end

  def schedule
    Utility.schedule_reminder(@participants, "A match you're in (#{@participants.map { |e| "<@#{e}>" }.join(" vs ")}, scheduled for *#{Utility.format_time(@time)}*) will begin in less than an hour!", @time - 1.hour)
  end

  def start_draft(guild, draft_role)
    client = TournamentBot.bot.client
    @participants.each { |p| client.add_guild_member_role(guild, p, draft_role) }
    @channel = client.create_guild_channel(guild, "draft-pick", Discord::ChannelType::GuildText, nil, nil).id.to_u64
    client.edit_channel_permissions(channel, draft_role, "role", Discord::Permissions::ReadMessages, Discord::Permissions::None)
    client.edit_channel_permissions(channel, guild, "role", Discord::Permissions::None, Discord::Permissions::ReadMessages)

    welcome_message = "Welcome to your draft phase. You can ban a map by typing `!ban <mapName>` and pick a map by "\
                      "typing `!pick <mapName>` (map names without the `<>`).\n"\
                      "You will take turns, banning / picking a map each until each player banned #{@tournament.bans_per_player} "\
                      "and picked #{@tournament.picks_per_player} map(s).\n<@#{@participants.first}> starts the first round.\n"\
                      "If you need any help, e.g. if you don't understand how to do something, ask a staff member to help you. "\
                      "They can also undo picks / bans for you in case you made a mistake.\n\n"\
                      "By the way, you don't need to spell map names correctly :)"

    welcome_message += "The maps `#{@tournament.default_bans.join("`, `")}` are banned by default, and can't be banned or picked "\
                      "by players or random selection. If you would like to allow them anyway, type `!allow`. "\
                      "All participants of this match will have to agree to this by also typing `!allow`." unless @tournament.default_bans.empty?

    client.create_message(@channel, welcome_message)
  end

  def picked?(map : String)
    @picks.values.each do |picks|
      return true if picks.includes?(map)
    end
  end
end
