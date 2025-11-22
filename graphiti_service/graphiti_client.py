"""
Wrapper around Graphiti core library for knowledge graph operations.
"""
import logging
from typing import List, Dict, Any, Optional
from datetime import datetime

# Graphiti will be imported when available
# from graphiti_core import Graphiti
from neo4j import GraphDatabase

from config import settings
from models import Entity, Edge

logger = logging.getLogger(__name__)


class GraphitiClient:
    """Client for interacting with Graphiti knowledge graph."""

    def __init__(self):
        """Initialize the Graphiti client."""
        self.driver = None
        self.graphiti = None
        self._connect()

    def _connect(self):
        """Connect to Neo4j database."""
        try:
            self.driver = GraphDatabase.driver(
                settings.neo4j_uri,
                auth=(settings.neo4j_user, settings.neo4j_password)
            )
            # Verify connection
            with self.driver.session() as session:
                session.run("RETURN 1")
            logger.info("Successfully connected to Neo4j")

            # Initialize Graphiti (when library is available)
            # self.graphiti = Graphiti(
            #     neo4j_uri=settings.neo4j_uri,
            #     neo4j_user=settings.neo4j_user,
            #     neo4j_password=settings.neo4j_password,
            #     llm_provider=settings.llm_provider,
            #     llm_api_key=settings.anthropic_api_key or settings.openai_api_key
            # )

        except Exception as e:
            logger.error(f"Failed to connect to Neo4j: {e}")
            raise

    def is_connected(self) -> bool:
        """Check if connected to Neo4j."""
        if not self.driver:
            return False
        try:
            with self.driver.session() as session:
                session.run("RETURN 1")
            return True
        except Exception:
            return False

    async def add_episode(
        self,
        content: str,
        source: Optional[str] = None,
        timestamp: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Add an episode to the knowledge graph.

        This will:
        1. Extract entities from the content using LLM
        2. Create nodes for entities
        3. Create relationships between entities
        4. Store temporal information
        """
        try:
            # TODO: Implement with Graphiti library when available
            # For now, create a simple node in Neo4j
            with self.driver.session() as session:
                result = session.run(
                    """
                    CREATE (e:Episode {
                        content: $content,
                        source: $source,
                        timestamp: datetime($timestamp),
                        created_at: datetime()
                    })
                    RETURN id(e) as episode_id
                    """,
                    content=content,
                    source=source or "semantic-graph-tui",
                    timestamp=timestamp or datetime.utcnow().isoformat()
                )
                record = result.single()
                episode_id = record["episode_id"] if record else None

                return {
                    "episode_id": str(episode_id),
                    "entities_extracted": 0,  # Placeholder
                    "edges_created": 0  # Placeholder
                }

        except Exception as e:
            logger.error(f"Error adding episode: {e}")
            raise

    async def search(
        self,
        query: str,
        limit: int = 10,
        include_entities: bool = True,
        include_edges: bool = True
    ) -> Dict[str, Any]:
        """
        Search the knowledge graph for relevant entities and relationships.

        Uses semantic search powered by LLM embeddings.
        """
        try:
            entities = []
            edges = []

            # TODO: Implement with Graphiti search when available
            # For now, do simple text search in Neo4j
            if include_entities:
                with self.driver.session() as session:
                    result = session.run(
                        """
                        MATCH (e:Episode)
                        WHERE e.content CONTAINS $query
                        RETURN id(e) as id, e.content as name, e.source as type,
                               e.created_at as created_at
                        LIMIT $limit
                        """,
                        query=query,
                        limit=limit
                    )

                    for record in result:
                        entities.append(Entity(
                            id=str(record["id"]),
                            name=record["name"][:100],  # Truncate for display
                            type=record.get("type"),
                            created_at=record.get("created_at")
                        ))

            return {
                "entities": entities,
                "edges": edges,
                "total_results": len(entities) + len(edges)
            }

        except Exception as e:
            logger.error(f"Error searching graph: {e}")
            raise

    async def get_relationships(
        self,
        entity_id: str,
        direction: str = "both",
        limit: int = 10
    ) -> List[Edge]:
        """Get relationships for a specific entity."""
        try:
            # TODO: Implement when Graphiti is integrated
            return []
        except Exception as e:
            logger.error(f"Error getting relationships: {e}")
            raise

    def close(self):
        """Close the Neo4j connection."""
        if self.driver:
            self.driver.close()
            logger.info("Closed Neo4j connection")


# Global client instance
_client: Optional[GraphitiClient] = None


def get_client() -> GraphitiClient:
    """Get or create the global Graphiti client."""
    global _client
    if _client is None:
        _client = GraphitiClient()
    return _client


def close_client():
    """Close the global Graphiti client."""
    global _client
    if _client:
        _client.close()
        _client = None
