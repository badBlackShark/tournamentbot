@[Discord::Plugin::Options()]
class TournamentBot::Help
  include Discord::Plugin

  def initialize
    @commands = YAML.parse(File.read("./src/commands.yml"))
  end

  @[Discord::Handler(event: :message_create, middleware: Command.new("!help"))]
  def help(payload, _ctx)
    bot = client.cache.try &.resolve_user(TournamentBot.config.client_id)
    return unless bot

    embed             = Discord::Embed.new
    embed.author      = Discord::EmbedAuthor.new(name: bot.username, icon_url: bot.avatar_url)
    embed.title       = "All commands for TournamentBot"
    embed.description = "Commands are displayed as **command**, **permission level needed**."

    fields = Array(Discord::EmbedField).new
    fields << Discord::EmbedField.new(
      name:  "General information commands",
      value: @commands["info"].as_a.map { |cmd| "#{cmd.as_h.keys.first}, #{cmd.as_h.values.first}" }.join("\n")
    )
    fields << Discord::EmbedField.new(
      name:  "Joining / leaving tournaments",
      value: @commands["misc"].as_a.map { |cmd| "#{cmd.as_h.keys.first}, #{cmd.as_h.values.first}" }.join("\n")
    )
    fields << Discord::EmbedField.new(
      name:  "Drafting",
      value: @commands["draft"].as_a.map { |cmd| "#{cmd.as_h.keys.first}, #{cmd.as_h.values.first}" }.join("\n")
    )
    fields << Discord::EmbedField.new(
      name:  "Managing matches",
      value: @commands["match_manage"].as_a.map { |cmd| "#{cmd.as_h.keys.first}, #{cmd.as_h.values.first}" }.join("\n")
    )
    fields << Discord::EmbedField.new(
      name:  "Managing a tournament",
      value: @commands["tournament_manage"].as_a.map { |cmd| "#{cmd.as_h.keys.first}, #{cmd.as_h.values.first}" }.join("\n")
    )

    embed.fields = fields
    embed.colour = 0xf700c5

    client.create_message(payload.channel_id, "", embed)
  end
end
