defmodule AutoAgent.Toolbox do
  require Logger

  @agent_path "lib/auto_agent/agent.ex"

  # --- 1. File Operations ---
  def read_agent_source do
    File.read!(@agent_path)
  end

  def write_agent_source(content) do
    File.write!(@agent_path, content)
  end

  # --- 2. The TDD Validator ---
  def verify_new_code(new_source) do
    # Write to a temp file first to test compilation
    temp_path = "lib/auto_agent/agent_temp.ex"

    try do
      # Rename module in source to avoid conflict during test
      test_source = String.replace(new_source, "defmodule AutoAgent.Server", "defmodule AutoAgent.ServerTemp")
      File.write!(temp_path, test_source)

      # Attempt to compile
      case Code.compile_file(temp_path) do
        [{module, _} | _] ->
          File.rm!(temp_path)
          :ok
        _ ->
          File.rm!(temp_path)
          {:error, "Compilation failed"}
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  # --- 3. Git Operations ---
  def git_commit(message) do
    System.cmd("git", ["add", "."])
    case System.cmd("git", ["commit", "-m", "[AutoAgent] #{message}"]) do
      {_, 0} -> :ok
      {err, _} -> {:error, err}
    end
  end
end
