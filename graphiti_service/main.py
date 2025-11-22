"""
Graphiti Knowledge Graph Service - FastAPI Application

This service provides an HTTP API for the Graphiti knowledge graph,
allowing the Elixir application to perform semantic analysis and
temporal graph operations.
"""
import logging
from datetime import datetime
from typing import List
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from models import (
    Episode,
    EpisodeResponse,
    SearchQuery,
    SearchResults,
    HealthResponse
)
from graphiti_client import get_client, close_client

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifespan - startup and shutdown."""
    # Startup
    logger.info(f"Starting {settings.service_name} v{settings.service_version}")
    try:
        client = get_client()
        if client.is_connected():
            logger.info("Successfully connected to Neo4j")
        else:
            logger.warning("Failed to connect to Neo4j - some features may not work")
    except Exception as e:
        logger.error(f"Error during startup: {e}")

    yield

    # Shutdown
    logger.info("Shutting down service...")
    close_client()


# Create FastAPI application
app = FastAPI(
    title=settings.service_name,
    version=settings.service_version,
    description="Knowledge graph service using Graphiti for semantic relationship analysis",
    lifespan=lifespan
)

# Add CORS middleware for web access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """
    Health check endpoint.

    Returns service status and connectivity information.
    """
    client = get_client()
    neo4j_connected = client.is_connected()
    llm_configured = bool(settings.anthropic_api_key or settings.openai_api_key)

    return HealthResponse(
        status="healthy" if neo4j_connected else "degraded",
        service=settings.service_name,
        version=settings.service_version,
        neo4j_connected=neo4j_connected,
        llm_configured=llm_configured,
        timestamp=datetime.utcnow()
    )


@app.post("/episodes", response_model=EpisodeResponse, status_code=status.HTTP_201_CREATED)
async def add_episode(episode: Episode):
    """
    Add a new episode (concept/idea) to the knowledge graph.

    This endpoint:
    1. Receives content from the Elixir application
    2. Extracts entities and relationships using LLM
    3. Stores them in the Neo4j graph database
    4. Returns information about extracted entities

    Args:
        episode: The episode to add

    Returns:
        Response with episode ID and extraction statistics

    Raises:
        HTTPException: If the operation fails
    """
    try:
        client = get_client()
        result = await client.add_episode(
            content=episode.content,
            source=episode.source,
            timestamp=episode.timestamp,
            metadata=episode.metadata
        )

        return EpisodeResponse(
            status="ok",
            message="Episode added successfully",
            episode_id=result.get("episode_id"),
            entities_extracted=result.get("entities_extracted", 0),
            edges_created=result.get("edges_created", 0)
        )

    except Exception as e:
        logger.error(f"Error adding episode: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to add episode: {str(e)}"
        )


@app.post("/search", response_model=SearchResults)
async def search_graph(query: SearchQuery):
    """
    Search the knowledge graph for relevant entities and relationships.

    Uses semantic search powered by LLM embeddings to find related concepts
    even when exact text matches don't exist.

    Args:
        query: Search parameters

    Returns:
        Matching entities and edges from the graph

    Raises:
        HTTPException: If the search fails
    """
    try:
        client = get_client()
        results = await client.search(
            query=query.query,
            limit=query.limit,
            include_entities=query.include_entities,
            include_edges=query.include_edges
        )

        return SearchResults(
            query=query.query,
            total_results=results.get("total_results", 0),
            entities=results.get("entities", []),
            edges=results.get("edges", [])
        )

    except Exception as e:
        logger.error(f"Error searching graph: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Search failed: {str(e)}"
        )


@app.get("/")
async def root():
    """Root endpoint with service information."""
    return {
        "service": settings.service_name,
        "version": settings.service_version,
        "status": "running",
        "endpoints": {
            "health": "/health",
            "add_episode": "POST /episodes",
            "search": "POST /search",
            "docs": "/docs"
        }
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level=settings.log_level.lower()
    )
