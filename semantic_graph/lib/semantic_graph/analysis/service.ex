defmodule SemanticGraph.Analysis.Service do
  @moduledoc """
  Orchestrates semantic analysis workflow.
  Ports functionality from src/analysis_service.zig
  """

  require Logger
  alias SemanticGraph.LLM.Client
  alias SemanticGraph.Resources.{Vertex, Edge}
  alias SemanticGraph.Graphiti

  @doc """
  Analyze a new idea against all existing ideas.
  Returns Task for async execution.
  """
  def analyze_new_idea_async(content) do
    Task.async(fn ->
      analyze_new_idea(content)
    end)
  end

  @doc """
  Synchronous version of analyze_new_idea.
  Creates vertex, analyzes relationships, creates edges.
  """
  def analyze_new_idea(content) do
    # 1. Create new vertex
    {:ok, vertex} = Vertex.add_idea(%{content: content, group: 0})

    # 2. Get all existing vertices (excluding the new one)
    existing_vertices =
      Vertex.list_all!()
      |> Enum.reject(&(&1.id == vertex.id))

    if length(existing_vertices) == 0 do
      # First idea, no relationships to analyze
      Logger.info("First idea added: #{content}")
      {:ok, %{vertex: vertex, relationships: []}}
    else
      # 3. Analyze relationships using LLM
      existing_contents = Enum.map(existing_vertices, & &1.content)

      Logger.info(
        "Analyzing '#{content}' against #{length(existing_vertices)} existing concepts"
      )

      {:ok, llm_relationships} = Client.analyze_relationships(content, existing_contents)

      # 4. Optionally enhance with Graphiti
      graphiti_relationships =
        case Graphiti.Integration.enhance_relationships(content, existing_contents) do
          {:ok, rels} ->
            Logger.debug("Graphiti provided #{length(rels)} additional relationships")
            rels

          _ ->
            []
        end

      # 5. Combine and deduplicate relationships
      all_relationships = llm_relationships ++ graphiti_relationships

      Logger.info("Found #{length(all_relationships)} total relationships")

      # 6. Create edges in graph
      edges =
        Enum.map(all_relationships, fn rel ->
          from_vertex = find_vertex_by_content(rel.from, [vertex | existing_vertices])
          to_vertex = find_vertex_by_content(rel.to, [vertex | existing_vertices])

          if from_vertex && to_vertex do
            case Edge.add_relationship(%{
                   from_vertex_id: from_vertex.id,
                   to_vertex_id: to_vertex.id,
                   relation_type: rel.type,
                   certainty: rel.certainty,
                   description: rel.description
                 }) do
              {:ok, edge} ->
                Logger.debug(
                  "Created edge: #{from_vertex.content} #{rel.type} #{to_vertex.content}"
                )

                edge

              {:error, reason} ->
                Logger.warn("Failed to create edge: #{inspect(reason)}")
                nil
            end
          else
            Logger.warn("Could not find vertices for relationship: #{inspect(rel)}")
            nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      # 7. Sync to Graphiti for temporal knowledge
      Graphiti.Integration.sync_concept(content)

      Logger.info("Analysis complete: created #{length(edges)} relationships")

      {:ok, %{vertex: vertex, relationships: edges}}
    end
  end

  defp find_vertex_by_content(content, vertices) do
    Enum.find(vertices, fn v ->
      String.downcase(String.trim(v.content)) == String.downcase(String.trim(content))
    end)
  end
end
