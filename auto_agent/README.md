# AutoAgent - A Self-Modifying Elixir Agent

A demonstration of a self-modifying Elixir agent that can evolve its own code at runtime using OTP hot code swapping.

## Architecture

```
auto_agent/
├── mix.exs                    # Project configuration
├── config/
│   └── config.exs             # Application configuration
└── lib/
    └── auto_agent/
        ├── application.ex     # OTP Application & Supervisor
        ├── brain.ex           # LLM Interface (Mocked for safety)
        ├── toolbox.ex         # Git, Tests, File I/O utilities
        └── agent.ex           # THE SELF-MODIFYING AGENT
```

## Components

### 1. AutoAgent.Server (agent.ex)
The core GenServer that can rewrite and hot-swap itself. It maintains state across code changes using OTP's `code_change/3` callback.

### 2. AutoAgent.Brain (brain.ex)
The LLM interface layer. Currently mocked for safety - looks for the keyword "logger" and modifies code accordingly. In production, this would connect to OpenAI, Claude, or another LLM API.

### 3. AutoAgent.Toolbox (toolbox.ex)
Provides utility functions for:
- Reading/writing the agent's source code
- Validating new code before deployment
- Git operations for version control

### 4. AutoAgent.Application (application.ex)
OTP Application that supervises the agent process.

## How It Works

1. **Self-Reflection**: The agent reads its own source code from disk
2. **Evolution**: An LLM (or mock) generates new code based on instructions
3. **Validation**: New code is syntax-checked before deployment
4. **Commit**: Valid code is written to disk and committed to git
5. **Hot Swap**: OTP's hot code swapping loads the new code without restarting the process
6. **State Migration**: The `code_change/3` callback preserves state across versions

## Installation

1. Install Elixir (if not already installed):
   ```bash
   # On Ubuntu/Debian
   sudo apt-get install elixir

   # On macOS with Homebrew
   brew install elixir
   ```

2. Install dependencies:
   ```bash
   cd auto_agent
   mix deps.get
   ```

3. Initialize git repository:
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   ```

## Usage

Start the application in interactive mode:

```bash
iex -S mix
```

### Check current behavior

```elixir
AutoAgent.Server.do_work()
# Output: [info] I am a basic agent.
```

### Command the agent to evolve

```elixir
# The mock brain looks for the word "logger" to trigger code modification
AutoAgent.Server.evolve("Add a new logger message to the perform_task function")
# Output: [info] Received evolution instruction: Add a new logger message...
#         [info] Evolution complete.
```

### Verify the change

```elixir
AutoAgent.Server.do_work()
# Output: [info] I am performing a task!
```

The agent has successfully modified and hot-swapped its own code!

## Safety Features

1. **Syntax Validation**: All new code is compiled in isolation before deployment
2. **Git Versioning**: Every evolution is committed to git for rollback capability
3. **Mocked LLM**: The Brain module is mocked by default to prevent unintended modifications
4. **State Preservation**: OTP's `code_change/3` ensures state survives code updates

## Connecting to a Real LLM

To connect to an actual LLM (OpenAI, Claude, etc.), modify `lib/auto_agent/brain.ex`:

```elixir
def evolve_code(current_source, instruction) do
  prompt = """
  You are a code evolution engine. Given the following Elixir code and instruction,
  rewrite the code to satisfy the instruction. Return ONLY valid Elixir code.

  Current code:
  #{current_source}

  Instruction: #{instruction}

  Return the complete modified code:
  """

  response = Req.post!("https://api.openai.com/v1/chat/completions",
    json: %{
      model: "gpt-4",
      messages: [%{role: "user", content: prompt}]
    },
    headers: %{"Authorization" => "Bearer #{System.get_env("OPENAI_API_KEY")}"}
  )

  response.body["choices"] |> List.first() |> get_in(["message", "content"])
end
```

## Warning

This is a demonstration of self-modifying code. In production:
- Implement comprehensive testing before code swaps
- Add code review/approval workflows
- Implement rollback mechanisms
- Use sandboxed execution environments
- Add comprehensive logging and monitoring

## License

MIT
