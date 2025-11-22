defmodule SemanticGraph.Analysis.ServiceTest do
  use ExUnit.Case
  alias SemanticGraph.Analysis.Service
  alias SemanticGraph.Resources.{Vertex, Edge}

  setup do
    # Clean graph before each test
    Vertex.list_all!() |> Enum.each(&Ash.destroy!/1)
    :ok
  end

  describe "analyze_new_idea/1" do
    test "creates vertex for first idea with no relationships" do
      {:ok, result} = Service.analyze_new_idea("Machine learning")

      assert result.vertex.content == "Machine learning"
      assert result.relationships == []

      # Verify vertex was created
      vertices = Vertex.list_all!()
      assert length(vertices) == 1
    end

    test "creates vertex and analyzes relationships for second idea" do
      # Add first idea
      {:ok, _} = Vertex.add_idea(%{content: "Deep learning"})

      # Add and analyze second idea
      {:ok, result} = Service.analyze_new_idea("Machine learning")

      assert result.vertex.content == "Machine learning"
      # Should find at least some relationships (mock or real)
      assert is_list(result.relationships)

      # Verify vertices were created
      vertices = Vertex.list_all!()
      assert length(vertices) == 2
    end

    test "handles multiple existing concepts" do
      # Add multiple concepts
      {:ok, _} = Vertex.add_idea(%{content: "Concept A"})
      {:ok, _} = Vertex.add_idea(%{content: "Concept B"})
      {:ok, _} = Vertex.add_idea(%{content: "Concept C"})

      # Analyze new concept
      {:ok, result} = Service.analyze_new_idea("Concept D")

      assert result.vertex.content == "Concept D"
      assert is_list(result.relationships)

      # Should have 4 vertices total
      vertices = Vertex.list_all!()
      assert length(vertices) == 4
    end
  end

  describe "analyze_new_idea_async/1" do
    test "returns a task that can be awaited" do
      task = Service.analyze_new_idea_async("Async concept")
      assert %Task{} = task

      # Wait for result
      {:ok, result} = Task.await(task)
      assert result.vertex.content == "Async concept"
    end
  end
end
