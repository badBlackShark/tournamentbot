require "yaml"
require "discordcr"
require "discordcr-plugin"
require "discordcr-middleware"
require "discordcr-middleware/middleware/prefix"

Dir.mkdir_p("./tournament-files")

require "./config"
require "./plugins/*"
require "./middlewares/*"
require "./tournaments/*"

module TournamentBot
  class Bot
    getter client : Discord::Client
    getter client_id : UInt64
    getter cache : Discord::Cache
    delegate run, stop, to: client

    def initialize(token : String, @client_id : UInt64)
      @client = Discord::Client.new(token: "Bot #{token}", client_id: @client_id)
      @cache = Discord::Cache.new(@client)
      @client.cache = @cache
      register_plugins
    end

    def register_plugins
      Discord::Plugin.plugins.each { |plugin| client.register(plugin) }
    end
  end

  class_getter! config : Config

  def self.run(config : Config)
    @@config = config
    bot = Bot.new(config.token, config.client_id)
    bot.run
  end
end
