# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :semantic_graph,
  ecto_repos: [SemanticGraph.Repo],
  generators: [timestamp_type: :utc_datetime]

config :semantic_graph, :ash_domains, [SemanticGraph.GraphAPI]

# Configures the endpoint
config :semantic_graph, SemanticGraphWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [json: SemanticGraphWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: SemanticGraph.PubSub,
  live_view: [signing_salt: "CHANGE_ME_IN_PROD"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Ash requires an explicit choice for how string length is counted, so that the
# `string_length` validation in Elixir and a data layer's own length function
# cannot disagree. Codepoints is the recommended setting: it is how SQL data
# layers count, so `max_length` also bounds the size of what gets stored.
config :ash, default_string_length_count: :codepoints

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
