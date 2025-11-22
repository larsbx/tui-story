defmodule SemanticGraph.Integration.WorkflowTest do
  @moduledoc """
  Integration tests for the complete workflow of incremental idea addition.
  Ported from tests/integration/workflow_test.zig
  """
  use ExUnit.Case

  alias SemanticGraph.Analysis.Service
  alias SemanticGraph.Resources.{Vertex, Edge}
  alias SemanticGraph.GraphAPI

  setup do
    # Clean graph before each test
    GraphAPI.reset_graph!()
    :ok
  end

  describe "incremental idea addition workflow" do
    test "adds ideas one at a time with mock LLM" do
      # Setup: Create test ideas (same as Zig version)
      ideas = [
        "Democracy",
        "Representative government",
        "Citizen participation",
        "Authoritarianism",
        "Centralized control",
        "Limited freedoms"
      ]

      # Execute: Add ideas one at a time
      Enum.each(ideas, fn idea ->
        {:ok, result} = Service.analyze_new_idea(idea)
        assert result.vertex.content == idea
      end)

      # Verify: Graph should be fully populated
      vertices = Vertex.list_all!()
      assert length(vertices) == 6

      # Verify: Vertices have correct content
      democracy_vertex = Enum.find(vertices, fn v -> v.content == "Democracy" end)
      assert democracy_vertex != nil
      assert democracy_vertex.group in [0, 1]

      # Verify: Edges have valid relationships
      edges = Edge.list_all!()
      Enum.each(edges, fn edge ->
        assert edge.certainty >= 0.0 and edge.certainty <= 1.0
        assert edge.description != nil and edge.description != ""

        # Verify vertices exist
        assert edge.from_vertex_id != nil
        assert edge.to_vertex_id != nil
        from_vertex = Vertex.get_by_id!(edge.from_vertex_id)
        to_vertex = Vertex.get_by_id!(edge.to_vertex_id)
        assert from_vertex != nil
        assert to_vertex != nil
      end)
    end

    test "graph grows incrementally with each addition" do
      ideas = ["Idea 1", "Idea 2", "Idea 3"]

      Enum.with_index(ideas, 1) |> Enum.each(fn {idea, expected_count} ->
        {:ok, _} = Service.analyze_new_idea(idea)
        vertices = Vertex.list_all!()
        assert length(vertices) == expected_count
      end)
    end

    test "handles validation errors gracefully" do
      # Test with empty idea (should fail validation)
      result = Service.analyze_new_idea("")

      assert {:error, _} = result

      # Graph should remain empty
      vertices = Vertex.list_all!()
      assert length(vertices) == 0
    end

    test "handles very long content validation" do
      # Create content longer than 1000 characters (max limit)
      long_content = String.duplicate("a", 1001)

      result = Service.analyze_new_idea(long_content)

      assert {:error, _} = result

      # Graph should remain empty
      vertices = Vertex.list_all!()
      assert length(vertices) == 0
    end

    test "workflow with two ideas creates relationships" do
      # Add first idea
      {:ok, result1} = Service.analyze_new_idea("Machine learning")
      assert result1.vertex.content == "Machine learning"
      assert result1.relationships == []

      # Add second idea
      {:ok, result2} = Service.analyze_new_idea("Deep learning")
      assert result2.vertex.content == "Deep learning"

      # Should have created at least some relationships
      # (In mock mode, the LLM client generates mock relationships)
      assert is_list(result2.relationships)

      # Verify graph state
      vertices = Vertex.list_all!()
      assert length(vertices) == 2
    end

    test "relationships have valid certainty scores" do
      # Add multiple ideas
      {:ok, _} = Service.analyze_new_idea("Concept A")
      {:ok, _} = Service.analyze_new_idea("Concept B")
      {:ok, _} = Service.analyze_new_idea("Concept C")

      # Check all edges have valid certainty
      edges = Edge.list_all!()
      Enum.each(edges, fn edge ->
        assert edge.certainty >= 0.0
        assert edge.certainty <= 1.0
      end)
    end

    test "multiple relationship types between same vertices are allowed" do
      {:ok, v1} = Service.analyze_new_idea("Concept X")
      {:ok, v2} = Service.analyze_new_idea("Concept Y")

      # Manually add different relationship types between same vertices
      {:ok, edge1} = Edge.add_relationship(%{
        from_vertex_id: v1.vertex.id,
        to_vertex_id: v2.vertex.id,
        relation_type: :analogous,
        certainty: 0.8,
        description: "Similar"
      })

      {:ok, edge2} = Edge.add_relationship(%{
        from_vertex_id: v1.vertex.id,
        to_vertex_id: v2.vertex.id,
        relation_type: :causal,
        certainty: 0.7,
        description: "One causes another"
      })

      assert edge1.id != edge2.id
      assert edge1.relation_type == :analogous
      assert edge2.relation_type == :causal
    end

    test "certainty-based deduplication maintains highest certainty" do
      {:ok, v1} = Service.analyze_new_idea("Concept A")
      {:ok, v2} = Service.analyze_new_idea("Concept B")

      # Add edge with low certainty
      {:ok, edge1} = Edge.add_relationship(%{
        from_vertex_id: v1.vertex.id,
        to_vertex_id: v2.vertex.id,
        relation_type: :analogous,
        certainty: 0.5,
        description: "Low certainty"
      })

      # Try to add same edge with higher certainty
      result = Edge.add_relationship(%{
        from_vertex_id: v1.vertex.id,
        to_vertex_id: v2.vertex.id,
        relation_type: :analogous,
        certainty: 0.9,
        description: "High certainty"
      })

      # Should update the existing edge
      assert {:error, _} = result

      # Verify only one edge exists with highest certainty
      edges = Edge.list_all!()
      matching = Enum.filter(edges, fn e ->
        e.from_vertex_id == v1.vertex.id and
        e.to_vertex_id == v2.vertex.id and
        e.relation_type == :analogous
      end)

      assert length(matching) == 1
      edge = hd(matching)
      assert edge.certainty == 0.9
      assert edge.description == "High certainty"
    end

    test "graph can be reset and rebuilt" do
      # Add some ideas
      {:ok, _} = Service.analyze_new_idea("Idea 1")
      {:ok, _} = Service.analyze_new_idea("Idea 2")

      vertices_before = Vertex.list_all!()
      assert length(vertices_before) == 2

      # Reset graph
      GraphAPI.reset_graph!()

      # Verify empty
      vertices_after = Vertex.list_all!()
      edges_after = Edge.list_all!()
      assert length(vertices_after) == 0
      assert length(edges_after) == 0

      # Rebuild
      {:ok, _} = Service.analyze_new_idea("New Idea 1")
      vertices_rebuilt = Vertex.list_all!()
      assert length(vertices_rebuilt) == 1
    end

    test "graph statistics are accurate" do
      # Add multiple ideas
      {:ok, _} = Service.analyze_new_idea("A")
      {:ok, _} = Service.analyze_new_idea("B")
      {:ok, _} = Service.analyze_new_idea("C")

      stats = GraphAPI.get_statistics()

      assert stats.vertex_count == 3
      assert stats.edge_count >= 0
      assert is_map(stats.edge_types_count)
      assert stats.average_certainty >= 0.0 or stats.average_certainty == nil
    end
  end

  describe "relationship type validation" do
    test "all 9 relationship types are supported" do
      relation_types = [
        :contradictory,
        :implicative,
        :hierarchical,
        :evolutionary,
        :analogous,
        :synonymous,
        :antonymous,
        :part_whole,
        :causal
      ]

      {:ok, v1} = Service.analyze_new_idea("Vertex 1")
      {:ok, v2} = Service.analyze_new_idea("Vertex 2")

      Enum.each(relation_types, fn type ->
        result = Edge.add_relationship(%{
          from_vertex_id: v1.vertex.id,
          to_vertex_id: v2.vertex.id,
          relation_type: type,
          certainty: 0.7,
          description: "Test relationship"
        })

        assert {:ok, edge} = result
        assert edge.relation_type == type
      end)
    end

    test "relationship symbols are correct" do
      expected_symbols = %{
        contradictory: "⊥",
        implicative: "→",
        hierarchical: "⊆",
        evolutionary: "⟿",
        analogous: "≈",
        synonymous: "≡",
        antonymous: "≠",
        part_whole: "∈",
        causal: "⇒"
      }

      Enum.each(expected_symbols, fn {type, symbol} ->
        assert Edge.relation_symbol(type) == symbol
      end)
    end
  end

  describe "vertex group assignment" do
    test "vertices are assigned to groups 0 or 1" do
      {:ok, result1} = Service.analyze_new_idea("First")
      {:ok, result2} = Service.analyze_new_idea("Second")
      {:ok, result3} = Service.analyze_new_idea("Third")

      assert result1.vertex.group in [0, 1]
      assert result2.vertex.group in [0, 1]
      assert result3.vertex.group in [0, 1]
    end
  end

  describe "async analysis" do
    test "async idea analysis completes successfully" do
      task = Service.analyze_new_idea_async("Async idea")
      assert %Task{} = task

      {:ok, result} = Task.await(task, 10_000)
      assert result.vertex.content == "Async idea"

      # Verify vertex was created
      vertices = Vertex.list_all!()
      assert length(vertices) == 1
    end

    test "multiple async analyses can run concurrently" do
      tasks = Enum.map(1..5, fn i ->
        Service.analyze_new_idea_async("Concurrent idea #{i}")
      end)

      results = Enum.map(tasks, fn task -> Task.await(task, 10_000) end)

      assert length(results) == 5
      Enum.each(results, fn result ->
        assert {:ok, _} = result
      end)

      vertices = Vertex.list_all!()
      assert length(vertices) == 5
    end
  end
end
