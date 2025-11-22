"""
Pydantic models for request/response validation.
"""
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field
from datetime import datetime


class Episode(BaseModel):
    """An episode (concept/idea) to add to the knowledge graph."""
    content: str = Field(..., min_length=1, max_length=10000, description="The content of the episode")
    source: Optional[str] = Field(default="semantic-graph-tui", description="Source of the episode")
    timestamp: Optional[str] = Field(default=None, description="ISO timestamp of the episode")
    metadata: Optional[Dict[str, Any]] = Field(default=None, description="Additional metadata")


class EpisodeResponse(BaseModel):
    """Response after adding an episode."""
    status: str
    message: str
    episode_id: Optional[str] = None
    entities_extracted: Optional[int] = None
    edges_created: Optional[int] = None


class SearchQuery(BaseModel):
    """Search query parameters."""
    query: str = Field(..., min_length=1, description="The search query")
    limit: int = Field(default=10, ge=1, le=100, description="Maximum number of results")
    include_entities: bool = Field(default=True, description="Include entities in results")
    include_edges: bool = Field(default=True, description="Include edges in results")


class Entity(BaseModel):
    """A knowledge graph entity."""
    id: str
    name: str
    type: Optional[str] = None
    properties: Optional[Dict[str, Any]] = None
    created_at: Optional[datetime] = None


class Edge(BaseModel):
    """A knowledge graph edge/relationship."""
    id: str
    from_entity: str
    to_entity: str
    relation_type: str
    certainty: Optional[float] = None
    created_at: Optional[datetime] = None
    properties: Optional[Dict[str, Any]] = None


class SearchResults(BaseModel):
    """Search results containing entities and edges."""
    query: str
    total_results: int
    entities: List[Entity] = []
    edges: List[Edge] = []


class HealthResponse(BaseModel):
    """Health check response."""
    status: str
    service: str
    version: str
    neo4j_connected: bool
    llm_configured: bool
    timestamp: datetime
