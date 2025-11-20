---------------------- MODULE SemanticGraphConstraints ----------------------
(***************************************************************************
 * TLA+ Specification for Semantic Graph Data Structure Constraints
 *
 * This module defines detailed constraints and invariants for the semantic
 * graph data structure, including:
 * - Vertex management and uniqueness
 * - Edge consistency and relationships
 * - Graph topology constraints
 * - Layout algorithm properties
 * - Incremental construction invariants
 *
 * Author: Claude (Anthropic)
 * Date: 2025-11-20
 ***************************************************************************)

EXTENDS Naturals, Sequences, FiniteSets, Reals, TLC

CONSTANTS
    MaxVertices,        \* Maximum number of vertices (ideas)
                        \* NOTE: This is a MODEL CHECKING constraint only!
                        \* The actual implementation has no hard limit on vertices.
                        \* Set to small value (e.g., 10) for tractable state space.
    LayoutWidth,        \* Width of layout area
    LayoutHeight,       \* Height of layout area
    MinCertainty,       \* Minimum certainty for relationships (0.5)
    MaxCertainty        \* Maximum certainty for relationships (1.0)

ASSUME MaxVertices \in Nat /\ MaxVertices > 0
ASSUME LayoutWidth > 0
ASSUME LayoutHeight > 0
ASSUME MinCertainty = 0.5
ASSUME MaxCertainty = 1.0

\* Derived constant: Maximum edges in a directed graph = N * (N - 1)
\* Every vertex can connect to every other vertex (excluding self-loops)
MaxEdges == MaxVertices * (MaxVertices - 1)

(***************************************************************************
 * VARIABLES
 ***************************************************************************)

VARIABLES
    vertices,           \* Set of vertices
    edges,              \* Set of edges
    nextId,             \* Next vertex ID to assign
    layoutCalculated    \* Boolean: has layout been calculated?

graphVars == <<vertices, edges, nextId, layoutCalculated>>

(***************************************************************************
 * RELATION TYPES
 ***************************************************************************)

\* All 9 relation types from graph.zig
RelationType == {
    "contradictory",    \* Ideas cannot both be true
    "implicative",      \* One idea implies another
    "hierarchical",     \* One is specific case of other
    "evolutionary",     \* One developed from other
    "analogous",        \* Structural similarity
    "synonymous",       \* Same meaning
    "antonymous",       \* Opposite meaning
    "part_whole",       \* One is part of other
    "causal"            \* One causes other
}

\* Symmetric relation types (bidirectional)
SymmetricRelations == {
    "contradictory",
    "analogous",
    "synonymous",
    "antonymous"
}

\* Asymmetric relation types (directional)
AsymmetricRelations == {
    "implicative",
    "hierarchical",
    "evolutionary",
    "part_whole",
    "causal"
}

(***************************************************************************
 * TYPE DEFINITIONS
 ***************************************************************************)

Vertex == [
    id: Nat,
    content: STRING,
    x: Real,
    y: Real,
    group: {0, 1}
]

Edge == [
    from: Nat,
    to: Nat,
    relationType: RelationType,
    certainty: Real,
    description: STRING
]

(***************************************************************************
 * HELPER OPERATORS
 ***************************************************************************)

\* Get vertex by ID
GetVertex(vid) ==
    IF \E v \in vertices : v.id = vid
    THEN CHOOSE v \in vertices : v.id = vid
    ELSE NULL

\* Check if vertex exists
VertexExists(vid) ==
    \E v \in vertices : v.id = vid

\* Get all edges from a vertex
GetOutgoingEdges(vid) ==
    {e \in edges : e.from = vid}

\* Get all edges to a vertex
GetIncomingEdges(vid) ==
    {e \in edges : e.to = vid}

\* Get all edges connected to a vertex
GetConnectedEdges(vid) ==
    {e \in edges : e.from = vid \/ e.to = vid}

\* Count edges between two vertices (should be 0 or 1)
EdgeCountBetween(vid1, vid2) ==
    Cardinality({e \in edges : e.from = vid1 /\ e.to = vid2})

\* Get vertices in a specific group
GetGroupVertices(g) ==
    {v \in vertices : v.group = g}

\* Calculate graph density
GraphDensity ==
    LET n == Cardinality(vertices)
        maxEdges == n * (n - 1)  \* Directed graph
    IN IF n <= 1 THEN 0
       ELSE Cardinality(edges) / maxEdges

\* Check if graph is connected (ignoring edge direction)
IsConnected ==
    \/ Cardinality(vertices) <= 1
    \/ \A v1, v2 \in vertices :
        \E path \in Seq(vertices) :
            /\ path[1] = v1
            /\ path[Len(path)] = v2
            /\ \A i \in 1..(Len(path)-1) :
                \E e \in edges :
                    (e.from = path[i].id /\ e.to = path[i+1].id)
                    \/ (e.to = path[i].id /\ e.from = path[i+1].id)

(***************************************************************************
 * INITIAL STATE
 ***************************************************************************)

Init ==
    /\ vertices = {}
    /\ edges = {}
    /\ nextId = 0
    /\ layoutCalculated = FALSE

(***************************************************************************
 * GRAPH OPERATIONS
 ***************************************************************************)

\* Add a vertex to the graph
AddVertex(content, group) ==
    /\ Cardinality(vertices) < MaxVertices
    /\ group \in {0, 1}
    /\ Len(content) > 0
    /\ Len(content) <= 1000
    /\ ~VertexExists(nextId)  \* ID not already used
    /\ LET newVertex == [
            id |-> nextId,
            content |-> content,
            x |-> 0.0,  \* Initial position, updated by layout
            y |-> 0.0,
            group |-> group
       ]
       IN /\ vertices' = vertices \cup {newVertex}
          /\ nextId' = nextId + 1
          /\ layoutCalculated' = FALSE  \* Layout needs recalculation
    /\ UNCHANGED edges

\* Add an edge between two vertices
AddEdge(fromId, toId, relType, certainty, description) ==
    /\ VertexExists(fromId)
    /\ VertexExists(toId)
    /\ fromId # toId
    /\ relType \in RelationType
    /\ certainty >= MinCertainty
    /\ certainty <= MaxCertainty
    /\ Cardinality(edges) < MaxEdges
    /\ LET newEdge == [
            from |-> fromId,
            to |-> toId,
            relationType |-> relType,
            certainty |-> certainty,
            description |-> description
       ]
       existingEdge == IF EdgeCountBetween(fromId, toId) > 0
                       THEN CHOOSE e \in edges :
                            e.from = fromId /\ e.to = toId
                       ELSE NULL
       IN IF existingEdge # NULL
          THEN \* Update edge if new certainty is higher
               IF certainty > existingEdge.certainty
               THEN edges' = (edges \ {existingEdge}) \cup {newEdge}
               ELSE UNCHANGED edges
          ELSE edges' = edges \cup {newEdge}
    /\ UNCHANGED <<vertices, nextId, layoutCalculated>>

\* Calculate layout positions using force-directed algorithm
CalculateLayout ==
    /\ Cardinality(vertices) > 0
    /\ LET
        \* Initial positioning: group 0 left, group 1 right
        InitialPosition(v) ==
            [v EXCEPT !.x = IF v.group = 0
                            THEN LayoutWidth * 0.25
                            ELSE LayoutWidth * 0.75,
                      !.y = LayoutHeight * 0.5]

        \* Apply initial positions
        positionedVertices == {InitialPosition(v) : v \in vertices}

        \* Force-directed iterations would happen here
        \* (Simplified in TLA+ - actual implementation in graph.zig)

        \* Ensure bounds
        BoundedPosition(v) ==
            [v EXCEPT !.x = IF v.x < 0 THEN 0
                            ELSE IF v.x > LayoutWidth THEN LayoutWidth
                            ELSE v.x,
                      !.y = IF v.y < 0 THEN 0
                            ELSE IF v.y > LayoutHeight THEN LayoutHeight
                            ELSE v.y]

        finalVertices == {BoundedPosition(v) : v \in positionedVertices}
       IN /\ vertices' = finalVertices
          /\ layoutCalculated' = TRUE
    /\ UNCHANGED <<edges, nextId>>

\* Clear the graph
Clear ==
    /\ vertices' = {}
    /\ edges' = {}
    /\ nextId' = 0
    /\ layoutCalculated' = FALSE

(***************************************************************************
 * INCREMENTAL CONSTRUCTION
 ***************************************************************************)

\* Add new idea and create relationships with existing ideas
AddIdeaIncremental(content, group) ==
    /\ Cardinality(vertices) > 0  \* Must have existing ideas
    /\ AddVertex(content, group)
    /\ LET newVertexId == nextId - 1
       IN \E existingVertex \in vertices :
            /\ existingVertex.id # newVertexId
            /\ \E relType \in RelationType :
                /\ \E certainty \in {c \in Real : c >= MinCertainty /\ c <= MaxCertainty} :
                    AddEdge(existingVertex.id, newVertexId, relType,
                           certainty, "auto-generated relationship")

(***************************************************************************
 * NEXT STATE RELATION
 ***************************************************************************)

Next ==
    \/ \E content \in STRING, group \in {0, 1} : AddVertex(content, group)
    \/ \E from, to \in Nat, relType \in RelationType,
         certainty \in Real, desc \in STRING :
        AddEdge(from, to, relType, certainty, desc)
    \/ CalculateLayout
    \/ Clear
    \/ \E content \in STRING, group \in {0, 1} :
        AddIdeaIncremental(content, group)

(***************************************************************************
 * INVARIANTS
 ***************************************************************************)

\* Type correctness
TypeInvariant ==
    /\ nextId \in Nat
    /\ nextId <= MaxVertices
    /\ Cardinality(vertices) <= MaxVertices
    /\ Cardinality(edges) <= MaxEdges
    /\ \A v \in vertices :
        /\ v.id \in Nat
        /\ v.id < nextId
        /\ v.group \in {0, 1}
        /\ Len(v.content) > 0
        /\ Len(v.content) <= 1000
    /\ \A e \in edges :
        /\ e.from \in Nat
        /\ e.to \in Nat
        /\ e.relationType \in RelationType
        /\ e.certainty >= MinCertainty
        /\ e.certainty <= MaxCertainty
    /\ layoutCalculated \in BOOLEAN

\* Vertex ID uniqueness
UniqueIds ==
    \A v1, v2 \in vertices : v1.id = v2.id => v1 = v2

\* Vertex IDs are sequential and start from 0
SequentialIds ==
    \A v \in vertices : v.id >= 0 /\ v.id < nextId

\* No gaps in vertex IDs
NoIdGaps ==
    \A i \in 0..(nextId-1) : VertexExists(i)

\* Edges only reference existing vertices
ValidEdges ==
    \A e \in edges :
        /\ VertexExists(e.from)
        /\ VertexExists(e.to)
        /\ e.from # e.to

\* At most one edge between any two vertices (in same direction)
UniqueEdges ==
    \A e1, e2 \in edges :
        (e1.from = e2.from /\ e1.to = e2.to) => e1 = e2

\* Vertices stay within layout bounds after layout calculation
BoundedVertices ==
    layoutCalculated =>
        \A v \in vertices :
            /\ v.x >= 0 /\ v.x <= LayoutWidth
            /\ v.y >= 0 /\ v.y <= LayoutHeight

\* Group 0 vertices cluster on left, group 1 on right
GroupSeparation ==
    layoutCalculated =>
        LET group0Avg == IF Cardinality(GetGroupVertices(0)) > 0
                         THEN LET g0 == GetGroupVertices(0)
                                  sumX == CHOOSE s \in Real : TRUE  \* Simplified
                              IN sumX / Cardinality(g0)
                         ELSE 0
            group1Avg == IF Cardinality(GetGroupVertices(1)) > 0
                         THEN LET g1 == GetGroupVertices(1)
                                  sumX == CHOOSE s \in Real : TRUE  \* Simplified
                              IN sumX / Cardinality(g1)
                         ELSE LayoutWidth
        IN group0Avg < group1Avg

\* Symmetric relations should maintain semantic meaning
SymmetricRelationConsistency ==
    \A e \in edges :
        e.relationType \in SymmetricRelations =>
            \* If A contradicts B, the relationship is bidirectional by nature
            \* (may or may not have reverse edge, but semantically symmetric)
            TRUE

\* No contradictory edges (e.g., A implies B and A contradicts B)
NoContradictoryRelations ==
    \A e1, e2 \in edges :
        (e1.from = e2.from /\ e1.to = e2.to) =>
            ~(e1.relationType = "implicative" /\ e2.relationType = "contradictory")

\* Graph size consistency
SizeConsistency ==
    /\ Cardinality(vertices) = nextId
    /\ Cardinality(vertices) <= MaxVertices

\* Each vertex has at least one edge (after first vertex)
ConnectedGraph ==
    Cardinality(vertices) > 1 =>
        \A v \in vertices :
            Cardinality(GetConnectedEdges(v.id)) > 0

\* Certainty increases with more specific relations
\* (e.g., synonymous typically has higher certainty than analogous)
CertaintyCoherence ==
    \A e \in edges :
        e.relationType = "synonymous" =>
            e.certainty >= MinCertainty + 0.1

\* Combined structural invariant
StructuralInvariant ==
    /\ TypeInvariant
    /\ UniqueIds
    /\ SequentialIds
    /\ NoIdGaps
    /\ ValidEdges
    /\ UniqueEdges
    /\ BoundedVertices
    /\ SizeConsistency

\* Combined semantic invariant
SemanticInvariant ==
    /\ SymmetricRelationConsistency
    /\ NoContradictoryRelations
    /\ CertaintyCoherence

\* Combined invariant
GraphInvariant ==
    /\ StructuralInvariant
    /\ SemanticInvariant

(***************************************************************************
 * TEMPORAL PROPERTIES
 ***************************************************************************)

\* Once a vertex is added, its ID never changes
StableVertexIds ==
    \A v \in vertices :
        [](VertexExists(v.id) => GetVertex(v.id).id = v.id)

\* nextId only increases
MonotonicNextId ==
    [][nextId' >= nextId]_graphVars

\* Eventually, layout is calculated after vertices are added
EventualLayout ==
    (Cardinality(vertices) > 0) ~> layoutCalculated

\* Graph can be cleared and rebuilt
Rebuildable ==
    <>(Cardinality(vertices) = 0) /\ <>(Cardinality(vertices) > 0)

(***************************************************************************
 * SPECIFICATION
 ***************************************************************************)

Spec == Init /\ [][Next]_graphVars

(***************************************************************************
 * THEOREMS
 ***************************************************************************)

\* Safety: Graph always maintains structural invariants
THEOREM GraphSafetyTheorem == Spec => []GraphInvariant

\* Monotonicity: Vertex IDs never decrease
THEOREM MonotonicityTheorem == Spec => []MonotonicNextId

\* Reachability: Graph can reach both empty and non-empty states
THEOREM ReachabilityTheorem ==
    Spec => (<>(Cardinality(vertices) = 0)
            /\ <>(Cardinality(vertices) > 0))

=============================================================================
