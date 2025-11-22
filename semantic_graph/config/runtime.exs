import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere.

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :semantic_graph, SemanticGraphWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base
end

# Graphiti service configuration
config :semantic_graph, :graphiti,
  base_url: System.get_env("GRAPHITI_BASE_URL", "http://localhost:8000")

# LLM Configuration
config :semantic_graph, :llm,
  provider: System.get_env("LLM_PROVIDER", "anthropic") |> String.to_atom(),
  model: System.get_env("LLM_MODEL", "claude-3-5-sonnet-20241022"),
  api_key: System.get_env("ANTHROPIC_API_KEY") || System.get_env("OPENAI_API_KEY"),
  endpoint: System.get_env("LLM_API_ENDPOINT")
