defmodule SemanticGraph.Graphiti.IntegrationTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias SemanticGraph.Graphiti.Integration
  import Tesla.Mock

  setup do
    # Stop the integration server if it's running
    if Process.whereis(Integration) do
      GenServer.stop(Integration)
      :timer.sleep(100)
    end

    :ok
  end

  describe "init/1" do
    test "starts with enabled state when Graphiti is healthy" do
      mock(fn %{method: :get, url: "http://localhost:8000/health"} ->
        json(%{"status" => "healthy"}, status: 200)
      end)

      log =
        capture_log(fn ->
          {:ok, pid} = Integration.start_link([])
          assert Integration.enabled?() == true
          GenServer.stop(pid)
        end)

      assert log =~ "Integration enabled"
    end

    test "starts with disabled state when Graphiti is unavailable" do
      mock(fn %{method: :get, url: "http://localhost:8000/health"} ->
        {:error, :econnrefused}
      end)

      log =
        capture_log(fn ->
          {:ok, pid} = Integration.start_link([])
          assert Integration.enabled?() == false
          GenServer.stop(pid)
        end)

      assert log =~ "Integration disabled"
    end
  end

  describe "sync_concept/1" do
    setup do
      mock(fn
        %{method: :get, url: "http://localhost:8000/health"} ->
          json(%{"status" => "healthy"}, status: 200)

        %{method: :post, url: "http://localhost:8000/episodes"} ->
          json(%{"status" => "ok"}, status: 200)
      end)

      {:ok, pid} = Integration.start_link([])
      on_exit(fn -> GenServer.stop(pid) end)
      :ok
    end

    test "syncs concept when enabled" do
      log =
        capture_log(fn ->
          assert :ok = Integration.sync_concept("Machine learning")
        end)

      assert log =~ "Synced concept: Machine learning"
    end

    test "returns ok even when Graphiti fails (graceful degradation)" do
      # Temporarily disable by mocking health check failure
      mock(fn
        %{method: :post, url: "http://localhost:8000/episodes"} ->
          {:error, :timeout}

        %{method: :get, url: "http://localhost:8000/health"} ->
          {:error, :econnrefused}
      end)

      # Wait for health check to disable integration
      :timer.sleep(200)

      # Should still return :ok even when disabled
      assert :ok = Integration.sync_concept("Test")
    end
  end

  describe "enhance_relationships/2" do
    setup do
      mock(fn
        %{method: :get, url: "http://localhost:8000/health"} ->
          json(%{"status" => "healthy"}, status: 200)

        %{method: :get, url: "http://localhost:8000/search"} ->
          json(
            %{
              "entities" => [],
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

      {:ok, pid} = Integration.start_link([])
      on_exit(fn -> GenServer.stop(pid) end)
      :ok
    end

    test "returns relationships when enabled" do
      assert {:ok, relationships} =
               Integration.enhance_relationships("Machine Learning", ["Deep Learning"])

      assert length(relationships) == 1
      relationship = List.first(relationships)
      assert relationship.type == :hierarchical
      assert relationship.certainty == 0.9
    end

    test "returns empty list when disabled" do
      # Mock health check failure to disable integration
      mock(fn
        %{method: :get, url: "http://localhost:8000/health"} ->
          {:error, :econnrefused}

        %{method: :get, url: "http://localhost:8000/search"} ->
          {:error, :econnrefused}
      end)

      # Wait for health check to run
      :timer.sleep(200)

      assert {:ok, []} = Integration.enhance_relationships("Test", [])
    end

    test "returns empty list when search fails" do
      mock(fn
        %{method: :get, url: "http://localhost:8000/health"} ->
          json(%{"status" => "healthy"}, status: 200)

        %{method: :get, url: "http://localhost:8000/search"} ->
          {:error, :timeout}
      end)

      log =
        capture_log(fn ->
          assert {:ok, []} = Integration.enhance_relationships("Test", [])
        end)

      assert log =~ "Search failed"
    end
  end

  describe "map_relation_type/1" do
    test "maps various relationship types correctly" do
      # Start integration to test private function indirectly
      mock(fn
        %{method: :get, url: "http://localhost:8000/health"} ->
          json(%{"status" => "healthy"}, status: 200)

        %{method: :get, url: "http://localhost:8000/search"} ->
          json(
            %{
              "entities" => [],
              "edges" => [
                %{"from" => "A", "to" => "B", "type" => "contradictory"},
                %{"from" => "C", "to" => "D", "type" => "implies"},
                %{"from" => "E", "to" => "F", "type" => "similar"},
                %{"from" => "G", "to" => "H", "type" => "unknown_type"}
              ]
            },
            status: 200
          )
      end)

      {:ok, pid} = Integration.start_link([])

      {:ok, relationships} = Integration.enhance_relationships("test", [])

      types = Enum.map(relationships, & &1.type)
      assert :contradictory in types
      assert :implicative in types
      assert :analogous in types

      GenServer.stop(pid)
    end
  end
end
