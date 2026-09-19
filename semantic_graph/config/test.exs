import Config

# Each test runs in its own transaction and is rolled back, so the suite needs
# no cleanup between tests and can stay async where the test says so.
config :semantic_graph, SemanticGraph.Repo,
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", "postgres"),
  hostname: System.get_env("PGHOST", "localhost"),
  database: "semantic_graph_test#{System.get_env("MIX_TEST_PARTITION")}",
  port: String.to_integer(System.get_env("PGPORT", "5432")),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

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

# The LLM client is Tesla-based and the suite mocks it. Without this the client
# falls back to the default adapter and makes real HTTP calls.
config :tesla, adapter: Tesla.Mock
