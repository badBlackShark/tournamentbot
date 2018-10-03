require "./tournamentbot"

config = TournamentBot::Config.load("./src/config.yml")
TournamentBot.run(config)
