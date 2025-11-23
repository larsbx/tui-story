# GEMINI.md

## Project Overview

This project, named "Semantic Relationship Graph TUI," is a terminal user interface (TUI) application designed for analyzing and visualizing semantic relationships between concepts. It leverages Large Language Models (LLMs) to perform this analysis. The core of the application is built with Elixir, utilizing the Phoenix and Ash frameworks, with Ratatouille for the TUI. It also includes a Python-based FastAPI service (`graphiti_service`) and uses Docker to manage services like Neo4j. The project places a strong emphasis on formal verification, with a suite of TLA+ specifications.

The application allows users to incrementally input concepts. Each new concept is automatically compared against all existing concepts, building a dense network of semantic relationships. These relationships are then visualized as an interactive graph in the terminal.

## Building and Running

To build and run the project, follow these steps:

1.  **Initial Setup:**
    This command sets up the necessary environment configurations.

    ```bash
    make setup
    ```

2.  **Start Services:**
    This command starts the dependent services, such as Neo4j and the Graphiti service, using Docker Compose.

    ```bash
    make start
    ```

3.  **Install Dependencies:**
    Navigate to the `semantic_graph` directory and install the Elixir dependencies.

    ```bash
    cd semantic_graph
    mix deps.get
    mix compile
    ```

4.  **Run the Application:**
    Finally, run the TUI application.

    ```bash
    iex -S mix
    ```

## Testing

The project includes a comprehensive test suite using ExUnit. To run the tests:

1.  Navigate to the `semantic_graph` directory:

    ```bash
    cd semantic_graph
    ```

2.  Run the test suite:

    ```bash
    mix test
    ```

## Development Conventions

The project follows a set of well-defined development conventions, as inferred from the documentation and file structure:

*   **Languages:** The primary language is Elixir, with Python used for the `graphiti_service`.
*   **Frameworks:** The project uses the Phoenix and Ash frameworks in the Elixir application and FastAPI for the Python service.
*   **Testing:** Testing is done using ExUnit, and the project has a dedicated `test` directory with a clear structure for unit and integration tests.
*   **Formal Verification:** The project uses TLA+ for formal verification of its core logic and data structures. The specifications are located in the `specs` directory.
*   **Documentation:** The project is well-documented, with a comprehensive `README.md`, architectural decision records (ADRs) in the `docs/architecture` directory, and various other markdown files explaining different aspects of the project.
*   **Dependency Management:** Elixir dependencies are managed with `mix`, and Python dependencies are managed with `pip` and a `requirements.txt` file.
*   **Version Control:** The project uses Git, and the presence of a `CHANGELOG.md` suggests a practice of keeping a record of changes for each version.
*   **Continuous Integration:** The project uses GitHub Actions for CI, with the configuration file located at `.github/workflows/ci.yml`. The CI pipeline enforces that all tests pass and that the code is correctly formatted.
