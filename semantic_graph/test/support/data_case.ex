defmodule SemanticGraph.DataCase do
  @moduledoc """
  Test case for anything that touches the graph.

  Each test runs inside its own transaction, which is rolled back afterwards,
  so tests no longer have to clean up after one another and two of them can run
  concurrently without fighting over the same rows.

  A test that is not `async: true` gets a *shared* connection, because the
  analysis path spawns work with `Task.async/1` and those processes need to see
  the same sandboxed connection as the test that started them.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import SemanticGraph.DataCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(SemanticGraph.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
