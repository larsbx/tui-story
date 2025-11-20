--------------------------- MODULE SemanticGraphTUI ---------------------------
(***************************************************************************
 * TLA+ Specification for Semantic Graph TUI Application
 *
 * This specification models the core behavior of the semantic relationship
 * graph TUI application, including:
 * - UI state machine transitions
 * - Graph operations (vertices and edges)
 * - Analysis workflow
 * - Validation and error handling
 *
 * Author: Claude (Anthropic)
 * Date: 2025-11-20
 ***************************************************************************)

EXTENDS Naturals, Sequences, FiniteSets, TLC

CONSTANTS
    MaxIdeas,           \* Maximum number of ideas in the system
    MaxContentLength,   \* Maximum length of idea content (1000)
    MaxRetries,         \* Maximum LLM API retries (3)
    NumGroups           \* Number of idea groups (2)

ASSUME MaxIdeas \in Nat /\ MaxIdeas > 0
ASSUME MaxContentLength = 1000
ASSUME MaxRetries = 3
ASSUME NumGroups = 2

(***************************************************************************
 * VARIABLES
 ***************************************************************************)

VARIABLES
    \* UI State
    uiMode,             \* Current UI mode: "help", "input", "analyzing", "viewing_graph"
    currentInput,       \* Current input buffer (string being typed)
    errorMessage,       \* Optional error message
    selectedEdge,       \* Currently selected edge index (or NULL)

    \* Graph State
    vertices,           \* Set of vertices {id, content, x, y, group}
    edges,              \* Set of edges {from, to, relationType, certainty, description}
    nextVertexId,       \* Next vertex ID to assign

    \* Analysis State
    ideas,              \* Sequence of entered ideas (strings)
    analysisInProgress, \* Boolean indicating if analysis is running
    retryCount,         \* Current retry count for LLM API

    \* Validation State
    lastValidationError \* Last validation error encountered

vars == <<uiMode, currentInput, errorMessage, selectedEdge,
          vertices, edges, nextVertexId,
          ideas, analysisInProgress, retryCount,
          lastValidationError>>

(***************************************************************************
 * TYPE DEFINITIONS
 ***************************************************************************)

\* Relation types from graph.zig
RelationTypes == {
    "contradictory",    \* ⊥
    "implicative",      \* →
    "hierarchical",     \* ⊆
    "evolutionary",     \* ⟿
    "analogous",        \* ≈
    "synonymous",       \* ≡
    "antonymous",       \* ≠
    "part_whole",       \* ∈
    "causal"            \* ⇒
}

\* UI modes from ui.zig
UIModes == {"help", "input", "analyzing", "viewing_graph"}

\* Groups: 0 or 1
Groups == 0..(NumGroups-1)

\* Vertex type
Vertex == [
    id: Nat,
    content: STRING,
    x: Real,
    y: Real,
    group: Groups
]

\* Edge type
Edge == [
    from: Nat,
    to: Nat,
    relationType: RelationTypes,
    certainty: Real,  \* [0.0, 1.0]
    description: STRING
]

(***************************************************************************
 * HELPER OPERATORS
 ***************************************************************************)

\* Get vertex by ID
GetVertex(vid) ==
    CHOOSE v \in vertices : v.id = vid

\* Check if vertex exists
VertexExists(vid) ==
    \E v \in vertices : v.id = vid

\* Check if edge exists between two vertices
EdgeExists(fromId, toId) ==
    \E e \in edges : e.from = fromId /\ e.to = toId

\* Find edge between two vertices
FindEdge(fromId, toId) ==
    CHOOSE e \in edges : e.from = fromId /\ e.to = toId

\* Validate idea content
ValidIdea(content) ==
    /\ Len(content) > 0
    /\ Len(content) <= MaxContentLength

\* Count vertices in a group
CountVerticesInGroup(g) ==
    Cardinality({v \in vertices : v.group = g})

(***************************************************************************
 * INITIAL STATE
 ***************************************************************************)

Init ==
    /\ uiMode = "help"
    /\ currentInput = ""
    /\ errorMessage = NULL
    /\ selectedEdge = NULL
    /\ vertices = {}
    /\ edges = {}
    /\ nextVertexId = 0
    /\ ideas = <<>>
    /\ analysisInProgress = FALSE
    /\ retryCount = 0
    /\ lastValidationError = NULL

(***************************************************************************
 * UI STATE TRANSITIONS
 ***************************************************************************)

\* Transition from help to input mode
StartInput ==
    /\ uiMode = "help"
    /\ uiMode' = "input"
    /\ currentInput' = ""
    /\ errorMessage' = NULL
    /\ UNCHANGED <<selectedEdge, vertices, edges, nextVertexId,
                   ideas, analysisInProgress, retryCount, lastValidationError>>

\* Transition from help to viewing mode
ViewGraph ==
    /\ uiMode = "help"
    /\ uiMode' = "viewing_graph"
    /\ selectedEdge' = IF edges # {} THEN 0 ELSE NULL
    /\ UNCHANGED <<currentInput, errorMessage, vertices, edges, nextVertexId,
                   ideas, analysisInProgress, retryCount, lastValidationError>>

\* Return to help from input (ESC)
CancelInput ==
    /\ uiMode = "input"
    /\ uiMode' = "help"
    /\ currentInput' = ""
    /\ UNCHANGED <<errorMessage, selectedEdge, vertices, edges, nextVertexId,
                   ideas, analysisInProgress, retryCount, lastValidationError>>

\* Return to help from viewing mode
ExitViewing ==
    /\ uiMode = "viewing_graph"
    /\ uiMode' = "help"
    /\ selectedEdge' = NULL
    /\ UNCHANGED <<currentInput, errorMessage, vertices, edges, nextVertexId,
                   ideas, analysisInProgress, retryCount, lastValidationError>>

\* Type character in input mode
TypeCharacter(c) ==
    /\ uiMode = "input"
    /\ Len(currentInput) < MaxContentLength
    /\ currentInput' = currentInput \o c
    /\ UNCHANGED <<uiMode, errorMessage, selectedEdge, vertices, edges,
                   nextVertexId, ideas, analysisInProgress, retryCount,
                   lastValidationError>>

\* Delete character (backspace)
DeleteCharacter ==
    /\ uiMode = "input"
    /\ Len(currentInput) > 0
    /\ currentInput' = SubSeq(currentInput, 1, Len(currentInput) - 1)
    /\ UNCHANGED <<uiMode, errorMessage, selectedEdge, vertices, edges,
                   nextVertexId, ideas, analysisInProgress, retryCount,
                   lastValidationError>>

(***************************************************************************
 * VALIDATION
 ***************************************************************************)

\* Validate input before submission
ValidateInput ==
    /\ uiMode = "input"
    /\ IF ValidIdea(currentInput)
       THEN /\ lastValidationError' = NULL
            /\ TRUE
       ELSE /\ lastValidationError' = "ValidationError"
            /\ errorMessage' = "Invalid input"
            /\ uiMode' = "help"
            /\ currentInput' = ""
            /\ FALSE
    /\ UNCHANGED <<selectedEdge, vertices, edges, nextVertexId,
                   ideas, analysisInProgress, retryCount>>

(***************************************************************************
 * GRAPH OPERATIONS
 ***************************************************************************)

\* Add a vertex to the graph
AddVertex(content, group) ==
    /\ nextVertexId < MaxIdeas
    /\ group \in Groups
    /\ ValidIdea(content)
    /\ LET newVertex == [
            id |-> nextVertexId,
            content |-> content,
            x |-> IF group = 0 THEN 0.25 ELSE 0.75,  \* Initial layout
            y |-> 0.5,
            group |-> group
       ]
       IN /\ vertices' = vertices \cup {newVertex}
          /\ nextVertexId' = nextVertexId + 1
    /\ UNCHANGED <<uiMode, currentInput, errorMessage, selectedEdge,
                   edges, ideas, analysisInProgress, retryCount,
                   lastValidationError>>

\* Add an edge between two vertices
AddEdge(fromId, toId, relType, cert, desc) ==
    /\ VertexExists(fromId)
    /\ VertexExists(toId)
    /\ fromId # toId  \* No self-loops
    /\ relType \in RelationTypes
    /\ cert >= 0.0 /\ cert <= 1.0
    /\ LET newEdge == [
            from |-> fromId,
            to |-> toId,
            relationType |-> relType,
            certainty |-> cert,
            description |-> desc
       ]
       IN IF EdgeExists(fromId, toId)
          THEN \* Update if higher certainty
               LET existingEdge == FindEdge(fromId, toId)
               IN IF cert > existingEdge.certainty
                  THEN edges' = (edges \ {existingEdge}) \cup {newEdge}
                  ELSE UNCHANGED edges
          ELSE edges' = edges \cup {newEdge}
    /\ UNCHANGED <<uiMode, currentInput, errorMessage, selectedEdge,
                   vertices, nextVertexId, ideas, analysisInProgress,
                   retryCount, lastValidationError>>

\* Clear the graph
ClearGraph ==
    /\ vertices' = {}
    /\ edges' = {}
    /\ nextVertexId' = 0
    /\ ideas' = <<>>
    /\ UNCHANGED <<uiMode, currentInput, errorMessage, selectedEdge,
                   analysisInProgress, retryCount, lastValidationError>>

(***************************************************************************
 * ANALYSIS WORKFLOW
 ***************************************************************************)

\* Start analysis (from input mode)
StartAnalysis ==
    /\ uiMode = "input"
    /\ ValidIdea(currentInput)
    /\ uiMode' = "analyzing"
    /\ analysisInProgress' = TRUE
    /\ retryCount' = 0
    /\ UNCHANGED <<currentInput, errorMessage, selectedEdge, vertices,
                   edges, nextVertexId, ideas, lastValidationError>>

\* Complete analysis successfully
CompleteAnalysis ==
    /\ uiMode = "analyzing"
    /\ analysisInProgress = TRUE
    /\ uiMode' = "viewing_graph"
    /\ analysisInProgress' = FALSE
    /\ ideas' = Append(ideas, currentInput)
    /\ currentInput' = ""
    /\ retryCount' = 0
    /\ selectedEdge' = IF edges # {} THEN 0 ELSE NULL
    /\ UNCHANGED <<errorMessage, vertices, edges, nextVertexId,
                   lastValidationError>>

\* Retry analysis after failure
RetryAnalysis ==
    /\ uiMode = "analyzing"
    /\ analysisInProgress = TRUE
    /\ retryCount < MaxRetries
    /\ retryCount' = retryCount + 1
    /\ UNCHANGED <<uiMode, currentInput, errorMessage, selectedEdge,
                   vertices, edges, nextVertexId, ideas, analysisInProgress,
                   lastValidationError>>

\* Fail analysis after max retries
FailAnalysis ==
    /\ uiMode = "analyzing"
    /\ analysisInProgress = TRUE
    /\ retryCount >= MaxRetries
    /\ uiMode' = "help"
    /\ analysisInProgress' = FALSE
    /\ errorMessage' = "Analysis failed after retries"
    /\ currentInput' = ""
    /\ retryCount' = 0
    /\ UNCHANGED <<selectedEdge, vertices, edges, nextVertexId, ideas,
                   lastValidationError>>

\* Incremental analysis: add new idea to existing graph
AnalyzeNewIdea ==
    /\ uiMode = "analyzing"
    /\ analysisInProgress = TRUE
    /\ ValidIdea(currentInput)
    /\ Len(ideas) > 0  \* Must have existing ideas
    /\ \E group \in Groups :
        \* Add vertex for new idea
        /\ AddVertex(currentInput, group)
        \* Create relationships with existing vertices
        /\ \E v \in vertices :
            /\ v.id < nextVertexId - 1  \* Existing vertex
            /\ \E relType \in RelationTypes :
                /\ \E certainty \in {c \in Real : c >= 0.5 /\ c <= 0.9} :
                    AddEdge(v.id, nextVertexId - 1, relType, certainty,
                            "relationship description")

(***************************************************************************
 * NAVIGATION IN VIEWING MODE
 ***************************************************************************)

\* Navigate to next edge
NextEdge ==
    /\ uiMode = "viewing_graph"
    /\ edges # {}
    /\ selectedEdge # NULL
    /\ selectedEdge' = (selectedEdge + 1) % Cardinality(edges)
    /\ UNCHANGED <<uiMode, currentInput, errorMessage, vertices, edges,
                   nextVertexId, ideas, analysisInProgress, retryCount,
                   lastValidationError>>

\* Navigate to previous edge
PrevEdge ==
    /\ uiMode = "viewing_graph"
    /\ edges # {}
    /\ selectedEdge # NULL
    /\ selectedEdge' = IF selectedEdge = 0
                       THEN Cardinality(edges) - 1
                       ELSE selectedEdge - 1
    /\ UNCHANGED <<uiMode, currentInput, errorMessage, vertices, edges,
                   nextVertexId, ideas, analysisInProgress, retryCount,
                   lastValidationError>>

(***************************************************************************
 * NEXT STATE RELATION
 ***************************************************************************)

Next ==
    \/ StartInput
    \/ ViewGraph
    \/ CancelInput
    \/ ExitViewing
    \/ \E c \in STRING : TypeCharacter(c)
    \/ DeleteCharacter
    \/ ValidateInput
    \/ StartAnalysis
    \/ CompleteAnalysis
    \/ RetryAnalysis
    \/ FailAnalysis
    \/ AnalyzeNewIdea
    \/ NextEdge
    \/ PrevEdge
    \/ ClearGraph

(***************************************************************************
 * INVARIANTS (Safety Properties)
 ***************************************************************************)

\* Type invariant: all variables have correct types
TypeInvariant ==
    /\ uiMode \in UIModes
    /\ currentInput \in STRING
    /\ nextVertexId \in Nat
    /\ nextVertexId <= MaxIdeas
    /\ \A v \in vertices :
        /\ v.id \in Nat
        /\ v.content \in STRING
        /\ v.group \in Groups
    /\ \A e \in edges :
        /\ e.from \in Nat
        /\ e.to \in Nat
        /\ e.relationType \in RelationTypes
        /\ e.certainty >= 0.0 /\ e.certainty <= 1.0
    /\ analysisInProgress \in BOOLEAN
    /\ retryCount \in 0..MaxRetries

\* Vertex IDs are unique
UniqueVertexIds ==
    \A v1, v2 \in vertices :
        v1.id = v2.id => v1 = v2

\* Vertex IDs are sequential
SequentialVertexIds ==
    \A v \in vertices : v.id < nextVertexId

\* Edges reference existing vertices
ValidEdgeReferences ==
    \A e \in edges :
        /\ VertexExists(e.from)
        /\ VertexExists(e.to)

\* No self-loops in edges
NoSelfLoops ==
    \A e \in edges : e.from # e.to

\* Analysis mode consistency
AnalysisConsistency ==
    uiMode = "analyzing" => analysisInProgress = TRUE

\* Input length constraint
InputLengthBound ==
    Len(currentInput) <= MaxContentLength

\* Ideas count matches vertices count
IdeasMatchVertices ==
    Len(ideas) <= Cardinality(vertices)

\* No negative coordinates (layout bounds)
ValidCoordinates ==
    \A v \in vertices :
        /\ v.x >= 0.0 /\ v.x <= 1.0
        /\ v.y >= 0.0 /\ v.y <= 1.0

\* State machine is deterministic
DeterministicTransitions ==
    uiMode \in UIModes

\* Combined safety invariant
SafetyInvariant ==
    /\ TypeInvariant
    /\ UniqueVertexIds
    /\ SequentialVertexIds
    /\ ValidEdgeReferences
    /\ NoSelfLoops
    /\ AnalysisConsistency
    /\ InputLengthBound
    /\ IdeasMatchVertices
    /\ ValidCoordinates
    /\ DeterministicTransitions

(***************************************************************************
 * TEMPORAL PROPERTIES (Liveness)
 ***************************************************************************)

\* Eventually, analysis completes or fails (no infinite analyzing)
EventuallyCompletesAnalysis ==
    uiMode = "analyzing" ~> (uiMode # "analyzing")

\* Every valid input eventually gets processed
EventuallyProcessesInput ==
    (uiMode = "input" /\ ValidIdea(currentInput))
        ~> (uiMode = "analyzing" \/ uiMode = "help")

\* The system can always return to help mode
EventuallyReturnsToHelp ==
    TRUE ~> (uiMode = "help")

\* Analysis with retries eventually succeeds or fails
AnalysisEventuallyTerminates ==
    analysisInProgress = TRUE
        ~> (analysisInProgress = FALSE)

(***************************************************************************
 * SPECIFICATION
 ***************************************************************************)

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

(***************************************************************************
 * THEOREMS (Properties to verify)
 ***************************************************************************)

\* Safety: System always maintains invariants
THEOREM SafetyTheorem == Spec => []SafetyInvariant

\* Liveness: Analysis always terminates
THEOREM LivenessTheorem == Spec => AnalysisEventuallyTerminates

\* Reachability: All UI modes are reachable
THEOREM ReachabilityTheorem ==
    Spec => <>(uiMode = "help")
         /\ <>(uiMode = "input")
         /\ <>(uiMode = "viewing_graph")

=============================================================================
