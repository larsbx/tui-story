defmodule AutoAgent.Server do
  use GenServer
  require Logger
  alias AutoAgent.{Brain, Toolbox}

  @vsn "1.0" # Version tracking

  # --- Client API ---
  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{history: [], data: %{}}, opts)
  end

  def evolve(instruction) do
    GenServer.call(__MODULE__, {:evolve, instruction}, 60_000)
  end

  def do_work do
    GenServer.call(__MODULE__, :work)
  end

  # --- Server Callbacks ---
  @impl true
  def init(state) do
    Logger.info("Agent Online. Version: #{@vsn}")
    {:ok, state}
  end

  @impl true
  def handle_call(:work, _from, state) do
    # By default, this does nothing. The Agent will write code here later.
    perform_task()
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:evolve, instruction}, _from, state) do
    Logger.info("Received evolution instruction: #{instruction}")

    # 1. Read Self
    current_source = Toolbox.read_agent_source()

    # 2. Generate New Self (LLM)
    new_source = Brain.evolve_code(current_source, instruction)

    # 3. Validate Syntax
    case Toolbox.verify_new_code(new_source) do
      :ok ->
        # 4. Commit to Disk
        Toolbox.write_agent_source(new_source)
        Toolbox.git_commit("Evolved: #{instruction}")

        # 5. TRIGGER HOT SWAP
        # We define the logic inline here to ensure clean context
        Code.compiler_options(ignore_module_conflict: true)

        # Suspend, Compile, Load, Resume
        :sys.suspend(self())
        Code.compile_file("lib/auto_agent/agent.ex")
        :sys.change_code(self(), __MODULE__, @vsn, [])
        :sys.resume(self())

        Logger.info("Evolution complete.")
        {:reply, :success, state}

      {:error, reason} ->
        Logger.error("Evolution failed syntax check: #{reason}")
        {:reply, {:error, reason}, state}
    end
  end

  # This callback is REQUIRED for hot swapping
  @impl true
  def code_change(_old_vsn, state, _extra) do
    Logger.info("Migrating State...")
    {:ok, state}
  end

  # --- DYNAMIC ZONE ---
  # The LLM will write functions below this line

  def perform_task do
    Logger.info("I am a basic agent.")
  end

  # [INSERTION POINT]
end
