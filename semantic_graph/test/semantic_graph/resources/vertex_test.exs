defmodule SemanticGraph.Resources.VertexTest do
  use ExUnit.Case, async: true

  alias SemanticGraph.Resources.Vertex

  describe "add_idea/1" do
    test "creates vertex with valid content" do
      {:ok, vertex} = Vertex.add_idea(%{content: "Machine learning"})
      assert vertex.content == "Machine learning"
      assert vertex.group == 0
      assert is_float(vertex.x)
      assert is_float(vertex.y)
      assert vertex.x == 0.0
      assert vertex.y == 0.0
    end

    test "creates vertex with custom group" do
      {:ok, vertex} = Vertex.add_idea(%{content: "Deep learning", group: 1})
      assert vertex.content == "Deep learning"
      assert vertex.group == 1
    end

    test "rejects empty content" do
      assert {:error, _} = Vertex.add_idea(%{content: ""})
    end

    test "rejects content over 1000 characters" do
      long_content = String.duplicate("a", 1001)
      assert {:error, _} = Vertex.add_idea(%{content: long_content})
    end

    test "trims whitespace from content" do
      {:ok, vertex} = Vertex.add_idea(%{content: "  Test Idea  "})
      assert vertex.content == "Test Idea"
    end

    test "rejects invalid group value" do
      assert {:error, _} = Vertex.add_idea(%{content: "Test", group: 2})
    end
  end

  describe "update_position/2" do
    test "updates vertex position" do
      {:ok, vertex} = Vertex.add_idea(%{content: "Test"})
      {:ok, updated} = Vertex.update_position(vertex, %{x: 10.5, y: 20.3})

      assert updated.x == 10.5
      assert updated.y == 20.3
      assert updated.content == "Test"
    end
  end

  describe "update_content/2" do
    test "updates vertex content" do
      {:ok, vertex} = Vertex.add_idea(%{content: "Original"})
      {:ok, updated} = Vertex.update_content(vertex, %{content: "Updated"})

      assert updated.content == "Updated"
    end

    test "rejects invalid content" do
      {:ok, vertex} = Vertex.add_idea(%{content: "Original"})
      assert {:error, _} = Vertex.update_content(vertex, %{content: ""})
    end
  end

  describe "list_all/0" do
    test "returns all vertices" do
      {:ok, v1} = Vertex.add_idea(%{content: "Idea 1"})
      {:ok, v2} = Vertex.add_idea(%{content: "Idea 2"})

      vertices = Vertex.list_all!()
      assert length(vertices) >= 2

      ids = Enum.map(vertices, & &1.id)
      assert v1.id in ids
      assert v2.id in ids
    end
  end

  describe "destroy/1" do
    test "deletes vertex" do
      {:ok, vertex} = Vertex.add_idea(%{content: "To be deleted"})
      assert {:ok, _} = Vertex.destroy(vertex)

      # Verify it's gone
      vertices = Vertex.list_all!()
      refute Enum.any?(vertices, fn v -> v.id == vertex.id end)
    end
  end
end
