ExUnit.start()

# Manual mode: every test checks out its own connection through
# SemanticGraph.DataCase and gives it back when it finishes.
Ecto.Adapters.SQL.Sandbox.mode(SemanticGraph.Repo, :manual)
