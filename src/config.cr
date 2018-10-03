module TournamentBot
  class Config
    include YAML::Serializable

    getter token : String
    getter owner_id : UInt64
    getter client_id : UInt64

    def initialize(@token : String, @owner_id : UInt64, @client_id : UInt64)
    end

    def self.load(filename)
      document = File.read(filename)
      from_yaml(document)
    rescue ex : YAML::ParseException
      abort("Failed to parse #{filename}:\n  #{ex.message}")
    end
  end
end
