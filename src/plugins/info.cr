@[Discord::Plugin::Options(middleware: DiscordMiddleware::Prefix.new("!"))]
class TournamentBot::Info
  include Discord::Plugin

  @[Discord::Handler(event: :message_create, middleware: Command.new("!info"))]
  def info(payload, _ctx)
    bot = client.cache.try &.resolve_user(TournamentBot.config.client_id)
    return unless bot

    embed = Discord::Embed.new
    embed.author = Discord::EmbedAuthor.new(name: bot.username, icon_url: bot.avatar_url)
    embed.description = "Developed by [badBlackShark](https://github.com/badBlackShark/), written in [Crystal](https://crystal-lang.org/)"
    embed.fields = [Discord::EmbedField.new(
        name: "Packages Used",
        value:
          "**[discordcr](https://github.com/meew0/discordcr)** *by meew0*

          **[discordcr-middleware](https://github.com/z64/discordcr-middleware)** *by z64*

          **[discordcr-plugin](https://github.com/z64/discordcr-plugin)** *by z64*"
      )
    ]
    embed.colour = 0xf700c5

    client.create_message(payload.channel_id, "", embed)
  end
end
