# Graphiti Knowledge Graph Service

FastAPI service providing HTTP API for Graphiti knowledge graph operations.

## Features

- **Episode Management**: Add concepts/ideas as episodes to the knowledge graph
- **Semantic Search**: LLM-powered search across entities and relationships
- **Temporal Queries**: Query graph state at different points in time
- **Entity Extraction**: Automatic entity and relationship extraction from text

## Setup

### Local Development

1. Create virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Configure environment:
```bash
cp .env.example .env
# Edit .env with your configuration
```

4. Start Neo4j (via Docker or local installation):
```bash
docker run -p 7687:7687 -p 7474:7474 \
  -e NEO4J_AUTH=neo4j/password \
  neo4j:5.14-community
```

5. Run the service:
```bash
uvicorn main:app --reload
```

The service will be available at http://localhost:8000

### Docker

Build and run with Docker:
```bash
docker build -t graphiti-service .
docker run -p 8000:8000 --env-file .env graphiti-service
```

## API Endpoints

### Health Check
```bash
GET /health
```

### Add Episode
```bash
POST /episodes
Content-Type: application/json

{
  "content": "Machine learning is a subset of artificial intelligence",
  "source": "semantic-graph-tui",
  "timestamp": "2024-11-22T12:00:00Z"
}
```

### Search
```bash
POST /search
Content-Type: application/json

{
  "query": "machine learning",
  "limit": 10,
  "include_entities": true,
  "include_edges": true
}
```

### Interactive Documentation

Visit http://localhost:8000/docs for interactive Swagger UI documentation.

## Architecture

The service acts as a bridge between the Elixir application and the Graphiti knowledge graph:

```
Elixir App → HTTP/JSON → FastAPI Service → Graphiti → Neo4j
```

## Configuration

Environment variables (see `.env.example`):

- `NEO4J_URI`: Neo4j connection URI
- `NEO4J_USER`: Neo4j username
- `NEO4J_PASSWORD`: Neo4j password
- `ANTHROPIC_API_KEY`: Anthropic API key for LLM
- `LLM_PROVIDER`: LLM provider (anthropic, openai)
- `LLM_MODEL`: Model name
- `LOG_LEVEL`: Logging level (DEBUG, INFO, WARNING, ERROR)

## Development

### Running Tests
```bash
pytest
```

### Code Quality
```bash
# Format code
black .

# Type checking
mypy .

# Linting
pylint graphiti_service
```

## License

See parent project LICENSE file.
