defmodule SemanticGraph.Graphiti.ClientTest do
  use ExUnit.Case, async: true
  import Tesla.Mock

  alias SemanticGraph.Graphiti.Client

  describe "health_check/0" do
    test "returns {:ok, true} when service is healthy" do
      mock(fn %{method: :get, url: "http://localhost:8000/health"} ->
        json(%{"status" => "healthy", "neo4j_connected" => true}, status: 200)
      end)

      assert {:ok, true} = Client.health_check()
    end

    test "returns {:ok, false} when service returns non-200" do
      mock(fn %{method: :get, url: "http://localhost:8000/health"} ->
        json(%{"status" => "unhealthy"}, status: 503)
      end)

      assert {:ok, false} = Client.health_check()
    end

    test "returns error when connection fails" do
      mock(fn %{method: :get, url: "http://localhost:8000/health"} ->
        {:error, :timeout}
      end)

      assert {:error, :timeout} = Client.health_check()
    end
  end

  describe "add_episode/1" do
    test "adds episode successfully" do
      mock(fn %{method: :post, url: "http://localhost:8000/episodes"} ->
        json(%{"status" => "ok", "message" => "Episode added", "episode_id" => "123"},
          status: 200
        )
      end)

      episode = %Client.Episode{
        content: "Machine learning is awesome",
        source: "test"
      }

      assert {:ok, response} = Client.add_episode(episode)
      assert response["status"] == "ok"
    end

    test "handles HTTP errors" do
      mock(fn %{method: :post, url: "http://localhost:8000/episodes"} ->
        json(%{"error" => "Invalid request"}, status: 400)
      end)

      episode = %Client.Episode{content: "Test"}

      assert {:error, {:http_error, 400, _}} = Client.add_episode(episode)
    end

    test "handles connection errors" do
      mock(fn %{method: :post, url: "http://localhost:8000/episodes"} ->
        {:error, :econnrefused}
      end)

      episode = %Client.Episode{content: "Test"}

      assert {:error, :econnrefused} = Client.add_episode(episode)
    end

    test "uses default source when not provided" do
      mock(fn %{
                method: :post,
                url: "http://localhost:8000/episodes",
                body: body
              } ->
        decoded_body = Jason.decode!(body)
        assert decoded_body["source"] == "semantic-graph-tui"
        json(%{"status" => "ok"}, status: 200)
      end)

      episode = %Client.Episode{content: "Test", source: nil}
      Client.add_episode(episode)
    end
  end

  describe "search/2" do
    test "searches successfully with results" do
      mock(fn %{method: :get, url: "http://localhost:8000/search"} ->
        json(
          %{
            "entities" => [
              %{"name" => "Machine Learning", "type" => "concept"}
            ],
            "edges" => [
              %{
                "from" => "Machine Learning",
                "to" => "Deep Learning",
                "type" => "hierarchical",
                "certainty" => 0.9
              }
            ]
          },
          status: 200
        )
      end)

      assert {:ok, %Client.SearchResult{entities: entities, edges: edges}} =
               Client.search("machine learning", 10)

      assert length(entities) == 1
      assert length(edges) == 1
    end

    test "handles empty results" do
      mock(fn %{method: :get, url: "http://localhost:8000/search"} ->
        json(%{"entities" => [], "edges" => []}, status: 200)
      end)

      assert {:ok, %Client.SearchResult{entities: [], edges: []}} =
               Client.search("nonexistent", 10)
    end

    test "handles HTTP errors" do
      mock(fn %{method: :get, url: "http://localhost:8000/search"} ->
        json(%{"error" => "Query too complex"}, status: 500)
      end)

      assert {:error, {:http_error, 500, _}} = Client.search("test", 10)
    end

    test "uses default limit when not provided" do
      mock(fn %{method: :get, url: "http://localhost:8000/search", query: query} ->
        assert query[:limit] == 10
        json(%{"entities" => [], "edges" => []}, status: 200)
      end)

      Client.search("test")
    end

    test "allows custom limit" do
      mock(fn %{method: :get, url: "http://localhost:8000/search", query: query} ->
        assert query[:limit] == 20
        json(%{"entities" => [], "edges" => []}, status: 200)
      end)

      Client.search("test", 20)
    end
  end
end
