require "./spec_helper"

describe TournamentBot::Bot do
  it "initializes" do
    TournamentBot::Bot.new("token", 123)
  end
end
