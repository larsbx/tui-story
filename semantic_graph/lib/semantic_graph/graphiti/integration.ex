defmodule SemanticGraph.Graphiti.Integration do
  @moduledoc """
  GenServer managing Graphiti integration with graceful fallback.
  Maintains connection state and provides sync operations.
  """

  use GenServer
  require Logger
  alias SemanticGraph.Graphiti.Client

  defmodule State do
    @moduledoc false
    defstruct enabled: false,
              last_health_check: nil,
              health_check_interval: 60_000
  end

  # Client API

  @doc """
  Start the Graphiti integration GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Check if Graphiti integration is currently enabled.
  """
  @spec enabled? :: boolean()
  def enabled? do
    GenServer.call(__MODULE__, :enabled?)
  end

  @doc """
  Sync a concept to Graphiti knowledge graph.
  Returns :ok even if Graphiti is unavailable (graceful degradation).
  """
  @spec sync_concept(String.t()) :: :ok | {:error, term()}
  def sync_concept(content) do
    GenServer.call(__MODULE__, {:sync_concept, content}, 35_000)
  end

  @doc """
  Enhance relationships using Graphiti's graph reasoning.
  Returns empty list if Graphiti unavailable.
  """
  @spec enhance_relationships(String.t(), list(String.t())) ::
          {:ok, list(map())} | {:error, term()}
  def enhance_relationships(concept, existing_concepts) do
    GenServer.call(
      __MODULE__,
      {:enhance_relationships, concept, existing_concepts},
      35_000
    )
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Perform initial health check
    enabled = check_health()

    if enabled do
      Logger.info("[Graphiti] Integration enabled - service healthy")
    else
      Logger.warning(
        "[Graphiti] Integration disabled - service unavailable, using fallback mode"
      )
    end

    # Schedule periodic health checks
    schedule_health_check()

    {:ok,
     %State{
       enabled: enabled,
       last_health_check: System.monotonic_time(:second)
     }}
  end

  @impl true
  def handle_call(:enabled?, _from, state) do
    {:reply, state.enabled, state}
  end

  @impl true
  def handle_call({:sync_concept, content}, _from, state) do
    if state.enabled do
      episode = %Client.Episode{
        content: content,
        source: "semantic-graph-tui"
      }

      case Client.add_episode(episode) do
        {:ok, _} ->
          Logger.debug("[Graphiti] Synced concept: #{String.slice(content, 0..50)}")
          {:reply, :ok, state}

        {:error, reason} ->
          Logger.error("[Graphiti] Failed to sync concept: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    else
      # Graceful degradation - don't fail if Graphiti unavailable
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:enhance_relationships, concept, _existing}, _from, state) do
    if state.enabled do
      case Client.search(concept, 10) do
        {:ok, results} ->
          # Convert Graphiti edges to our relationship format
          relationships = convert_graphiti_edges(results.edges)
          {:reply, {:ok, relationships}, state}

        {:error, reason} ->
          Logger.error("[Graphiti] Search failed: #{inspect(reason)}")
          {:reply, {:ok, []}, state}
      end
    else
      # Return empty list if disabled
      {:reply, {:ok, []}, state}
    end
  end

  @impl true
  def handle_info(:health_check, state) do
    enabled = check_health()

    if enabled != state.enabled do
      if enabled do
        Logger.info("[Graphiti] Service restored - enabling integration")
      else
        Logger.warning("[Graphiti] Service down - disabling integration")
      end
    end

    schedule_health_check()

    {:noreply,
     %{state | enabled: enabled, last_health_check: System.monotonic_time(:second)}}
  end

  # Private Helpers

  defp check_health do
    case Client.health_check() do
      {:ok, true} -> true
      _ -> false
    end
  end

  defp schedule_health_check do
    Process.send_after(self(), :health_check, 60_000)
  end

  defp convert_graphiti_edges(graphiti_edges) when is_list(graphiti_edges) do
    # Map Graphiti edge format to SemanticGraph.Resources.Edge format
    Enum.map(graphiti_edges, fn edge ->
      %{
        from: edge["from"] || edge["source"],
        to: edge["to"] || edge["target"],
        type: map_relation_type(edge["type"] || edge["relation_type"]),
        certainty: edge["certainty"] || 0.7,
        description: edge["description"] || ""
      }
    end)
  end

  defp convert_graphiti_edges(_), do: []

  defp map_relation_type(type) when is_binary(type) do
    # Map Graphiti relationship types to our 9 types
    case String.downcase(type) do
      "contradictory" -> :contradictory
      "contradiction" -> :contradictory
      "implies" -> :implicative
      "implication" -> :implicative
      "implicative" -> :implicative
      "hierarchical" -> :hierarchical
      "hierarchy" -> :hierarchical
      "parent_child" -> :hierarchical
      "evolutionary" -> :evolutionary
      "evolution" -> :evolutionary
      "analogous" -> :analogous
      "analogy" -> :analogous
      "similar" -> :analogous
      "synonymous" -> :synonymous
      "synonym" -> :synonymous
      "same" -> :synonymous
      "antonymous" -> :antonymous
      "antonym" -> :antonymous
      "opposite" -> :antonymous
      "part_whole" -> :part_whole
      "part_of" -> :part_whole
      "contains" -> :part_whole
      "causal" -> :causal
      "cause" -> :causal
      "causes" -> :causal
      # Default to analogous for unknown types
      _ -> :analogous
    end
  end

  defp map_relation_type(_), do: :analogous
end
