defmodule SemanticGraph.Graphiti.Client do
  @moduledoc """
  HTTP client for Graphiti knowledge graph service.
  Implements circuit breaker and retry logic.
  """

  use Tesla

  plug Tesla.Middleware.BaseUrl, base_url()
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Headers, [{"content-type", "application/json"}]

  plug Tesla.Middleware.Retry,
    delay: 1000,
    max_retries: 3,
    max_delay: 8_000,
    should_retry: fn
      {:ok, %{status: status}} when status in 500..599 -> true
      {:ok, _} -> false
      {:error, _} -> true
    end

  plug Tesla.Middleware.Timeout, timeout: 30_000

  defmodule Episode do
    @moduledoc """
    Represents an episode (concept) to be added to the knowledge graph.
    """
    @type t :: %__MODULE__{
            content: String.t(),
            source: String.t() | nil,
            timestamp: String.t() | nil
          }
    defstruct [:content, :source, :timestamp]
  end

  defmodule SearchResult do
    @moduledoc """
    Represents search results from the knowledge graph.
    """
    @type t :: %__MODULE__{
            entities: list(map()),
            edges: list(map())
          }
    defstruct entities: [], edges: []
  end

  @doc """
  Check if Graphiti service is healthy and available.
  """
  @spec health_check() :: {:ok, boolean()} | {:error, term()}
  def health_check do
    case get("/health") do
      {:ok, %{status: 200}} -> {:ok, true}
      {:ok, %{status: _}} -> {:ok, false}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Add an episode (concept) to the knowledge graph.
  """
  @spec add_episode(Episode.t()) :: {:ok, map()} | {:error, term()}
  def add_episode(%Episode{} = episode) do
    body = %{
      content: episode.content,
      source: episode.source || "semantic-graph-tui",
      timestamp: episode.timestamp
    }

    case post("/episodes", body) do
      {:ok, %{status: 200, body: response}} ->
        {:ok, response}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Search the knowledge graph for relationships.
  """
  @spec search(String.t(), non_neg_integer()) ::
          {:ok, SearchResult.t()} | {:error, term()}
  def search(query, limit \\ 10) do
    case get("/search", query: [query: query, limit: limit]) do
      {:ok, %{status: 200, body: body}} ->
        result = %SearchResult{
          entities: body["entities"] || [],
          edges: body["edges"] || []
        }

        {:ok, result}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp base_url do
    System.get_env("GRAPHITI_BASE_URL", "http://localhost:8000")
  end
end
