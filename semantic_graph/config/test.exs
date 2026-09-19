import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :semantic_graph, SemanticGraphWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_CHANGE_IN_PRODUCTION_minimum_64_characters!",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# The TUI needs a terminal; the test run does not have one.
config :semantic_graph, start_tui: false

# The suite drives the Graphiti client with Tesla.Mock. Without this the client
# falls back to the default adapter and makes real HTTP calls, so every mocked
# expectation fails and each one first burns the retry and timeout middleware.
config :tesla, adapter: Tesla.Mock
