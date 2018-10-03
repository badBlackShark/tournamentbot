require "yaml"
require "time"
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
    getter client    : Discord::Client
    getter client_id : UInt64
    getter cache     : Discord::Cache
    delegate run, stop, to: client

    def initialize(token : String, @client_id : UInt64)
      @client       = Discord::Client.new(token: "Bot #{token}", client_id: @client_id)
      @cache        = Discord::Cache.new(@client)
      @client.cache = @cache
      register_plugins
    end

    def register_plugins
      Discord::Plugin.plugins.each { |plugin| client.register(plugin) }
    end
  end

<<<<<<< HEAD
  AUTH      = YAML.parse(File.read("./src/config.yml"))
  OWNER_ID  = AUTH["owner"].as_i.to_u64
  CLIENT_ID = AUTH["client_id"].as_i.to_u64
  FORMATTER = Time::Format.new("%A, %-d.%-m.2018 at %I:%M%p UTC+0", Time::Location.fixed("UTC", 0))
=======
  class_getter! config : Config
>>>>>>> b7110f2311e5599a362100690148accdfbe90f51

  def self.run(config : Config)
    @@config = config
    bot = Bot.new(config.token, config.client_id)
    bot.run
  end
end
