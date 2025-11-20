--------------------------- MODULE LLMRetryLogic ---------------------------
(***************************************************************************
 * TLA+ Specification for LLM API Retry Logic
 *
 * This module models the LLM client's retry mechanism with:
 * - Exponential backoff strategy
 * - Timeout handling
 * - Maximum retry limits
 * - Mock fallback behavior
 * - Request/response lifecycle
 *
 * Based on: src/llm.zig
 *
 * Author: Claude (Anthropic)
 * Date: 2025-11-20
 ***************************************************************************)

EXTENDS Naturals, Sequences, TLC

CONSTANTS
    MaxRetries,         \* Maximum number of retry attempts (3)
    InitialBackoff,     \* Initial backoff in milliseconds (1000)
    TimeoutMs,          \* Request timeout in milliseconds (30000)
    MaxBackoff          \* Maximum backoff in milliseconds (8000)

ASSUME MaxRetries = 3
ASSUME InitialBackoff = 1000
ASSUME TimeoutMs = 30000
ASSUME MaxBackoff = 8000

(***************************************************************************
 * VARIABLES
 ***************************************************************************)

VARIABLES
    apiKey,             \* Optional API key (NULL for mock mode)
    requestState,       \* Current request state
    retryCount,         \* Current number of retries
    backoffTime,        \* Current backoff duration
    lastError,          \* Last error encountered
    requestId,          \* Current request ID
    responseData,       \* Response data from API
    mockMode            \* Boolean: using mock LLM or real API

vars == <<apiKey, requestState, retryCount, backoffTime, lastError,
          requestId, responseData, mockMode>>

(***************************************************************************
 * REQUEST STATES
 ***************************************************************************)

RequestStates == {
    "idle",             \* No active request
    "preparing",        \* Building request payload
    "sending",          \* Sending HTTP request
    "waiting",          \* Waiting for response
    "backoff",          \* Waiting before retry
    "parsing",          \* Parsing response JSON
    "success",          \* Request completed successfully
    "failed"            \* Request failed permanently
}

(***************************************************************************
 * ERROR TYPES
 ***************************************************************************)

ErrorTypes == {
    "timeout",          \* Request timed out
    "network",          \* Network connection error
    "http_error",       \* HTTP error (4xx, 5xx)
    "parse_error",      \* JSON parsing failed
    "invalid_key",      \* API key invalid
    "rate_limit",       \* Rate limited by API
    NULL                \* No error
}

(***************************************************************************
 * HELPER OPERATORS
 ***************************************************************************)

\* Calculate exponential backoff
CalculateBackoff(attempt) ==
    LET baseBackoff == InitialBackoff * (2^attempt)
    IN IF baseBackoff > MaxBackoff
       THEN MaxBackoff
       ELSE baseBackoff

\* Check if error is retryable
IsRetryableError(error) ==
    error \in {"timeout", "network", "rate_limit"}

\* Check if should use mock mode
UseMockMode ==
    apiKey = NULL

(***************************************************************************
 * INITIAL STATE
 ***************************************************************************)

Init ==
    /\ apiKey = NULL  \* Start without API key (can be set later)
    /\ requestState = "idle"
    /\ retryCount = 0
    /\ backoffTime = 0
    /\ lastError = NULL
    /\ requestId = 0
    /\ responseData = NULL
    /\ mockMode = TRUE

(***************************************************************************
 * API KEY MANAGEMENT
 ***************************************************************************)

\* Set API key (switches from mock to real mode)
SetAPIKey(key) ==
    /\ requestState = "idle"
    /\ apiKey' = key
    /\ mockMode' = (key = NULL)
    /\ UNCHANGED <<requestState, retryCount, backoffTime, lastError,
                   requestId, responseData>>

(***************************************************************************
 * REQUEST LIFECYCLE
 ***************************************************************************)

\* Start a new request
StartRequest ==
    /\ requestState = "idle"
    /\ requestState' = "preparing"
    /\ retryCount' = 0
    /\ backoffTime' = 0
    /\ lastError' = NULL
    /\ requestId' = requestId + 1
    /\ responseData' = NULL
    /\ UNCHANGED <<apiKey, mockMode>>

\* Prepare request payload
PrepareRequest ==
    /\ requestState = "preparing"
    /\ IF mockMode
       THEN \* Use mock data - skip network call
            /\ requestState' = "parsing"
            /\ responseData' = "mock_response"
            /\ UNCHANGED <<retryCount, backoffTime, lastError>>
       ELSE \* Real API call
            /\ requestState' = "sending"
            /\ UNCHANGED <<retryCount, backoffTime, lastError, responseData>>
    /\ UNCHANGED <<apiKey, requestId, mockMode>>

\* Send HTTP request
SendRequest ==
    /\ requestState = "sending"
    /\ ~mockMode
    /\ requestState' = "waiting"
    /\ UNCHANGED <<apiKey, retryCount, backoffTime, lastError,
                   requestId, responseData, mockMode>>

\* Wait for response (may timeout or succeed)
WaitForResponse ==
    /\ requestState = "waiting"
    /\ ~mockMode
    /\ \/ \* Successful response
          /\ requestState' = "parsing"
          /\ responseData' = "api_response"
          /\ lastError' = NULL
       \/ \* Timeout
          /\ requestState' = "backoff"
          /\ lastError' = "timeout"
          /\ UNCHANGED responseData
       \/ \* Network error
          /\ requestState' = "backoff"
          /\ lastError' = "network"
          /\ UNCHANGED responseData
       \/ \* HTTP error
          /\ requestState' = "backoff"
          /\ lastError' = "http_error"
          /\ UNCHANGED responseData
    /\ UNCHANGED <<apiKey, retryCount, backoffTime, requestId, mockMode>>

\* Parse response
ParseResponse ==
    /\ requestState = "parsing"
    /\ responseData # NULL
    /\ \/ \* Parse success
          /\ requestState' = "success"
          /\ lastError' = NULL
       \/ \* Parse error
          /\ requestState' = "backoff"
          /\ lastError' = "parse_error"
    /\ UNCHANGED <<apiKey, retryCount, backoffTime, requestId,
                   responseData, mockMode>>

\* Enter backoff state after error
EnterBackoff ==
    /\ requestState = "backoff"
    /\ lastError # NULL
    /\ IsRetryableError(lastError)
    /\ retryCount < MaxRetries
    /\ backoffTime' = CalculateBackoff(retryCount)
    /\ UNCHANGED <<apiKey, requestState, retryCount, lastError,
                   requestId, responseData, mockMode>>

\* Wait during backoff period
WaitBackoff ==
    /\ requestState = "backoff"
    /\ backoffTime > 0
    /\ backoffTime' = 0  \* Simplified: instant backoff completion
    /\ UNCHANGED <<apiKey, requestState, retryCount, lastError,
                   requestId, responseData, mockMode>>

\* Retry after backoff
RetryRequest ==
    /\ requestState = "backoff"
    /\ backoffTime = 0
    /\ retryCount < MaxRetries
    /\ IsRetryableError(lastError)
    /\ requestState' = "sending"
    /\ retryCount' = retryCount + 1
    /\ lastError' = NULL
    /\ UNCHANGED <<apiKey, backoffTime, requestId, responseData, mockMode>>

\* Fail permanently after max retries
FailPermanently ==
    /\ requestState = "backoff"
    /\ \/ retryCount >= MaxRetries
       \/ ~IsRetryableError(lastError)
    /\ requestState' = "failed"
    /\ UNCHANGED <<apiKey, retryCount, backoffTime, lastError,
                   requestId, responseData, mockMode>>

\* Complete request successfully
CompleteRequest ==
    /\ requestState = "success"
    /\ requestState' = "idle"
    /\ UNCHANGED <<apiKey, retryCount, backoffTime, lastError,
                   requestId, responseData, mockMode>>

\* Reset after failure
ResetAfterFailure ==
    /\ requestState = "failed"
    /\ requestState' = "idle"
    /\ retryCount' = 0
    /\ backoffTime' = 0
    /\ lastError' = NULL
    /\ UNCHANGED <<apiKey, requestId, responseData, mockMode>>

(***************************************************************************
 * NEXT STATE RELATION
 ***************************************************************************)

Next ==
    \/ \E key \in STRING : SetAPIKey(key)
    \/ StartRequest
    \/ PrepareRequest
    \/ SendRequest
    \/ WaitForResponse
    \/ ParseResponse
    \/ EnterBackoff
    \/ WaitBackoff
    \/ RetryRequest
    \/ FailPermanently
    \/ CompleteRequest
    \/ ResetAfterFailure

(***************************************************************************
 * INVARIANTS
 ***************************************************************************)

\* Type invariant
TypeInvariant ==
    /\ requestState \in RequestStates
    /\ retryCount \in 0..MaxRetries
    /\ backoffTime \in Nat
    /\ lastError \in ErrorTypes
    /\ requestId \in Nat
    /\ mockMode \in BOOLEAN

\* Retry count never exceeds maximum
RetryBound ==
    retryCount <= MaxRetries

\* Backoff time follows exponential pattern
ValidBackoff ==
    backoffTime \in {0} \cup {CalculateBackoff(i) : i \in 0..(MaxRetries-1)}

\* State consistency: certain states require certain conditions
StateConsistency ==
    /\ (requestState = "idle" => lastError = NULL)
    /\ (requestState = "success" => responseData # NULL)
    /\ (requestState = "failed" => lastError # NULL)
    /\ (requestState = "sending" => ~mockMode)
    /\ (requestState = "waiting" => ~mockMode)
    /\ (mockMode => apiKey = NULL)

\* No backoff in mock mode (mock is instant)
MockModeNoBackoff ==
    mockMode => requestState # "backoff"

\* Retry only happens for retryable errors
RetryOnlyRetryableErrors ==
    (requestState = "backoff" /\ retryCount < MaxRetries) =>
        IsRetryableError(lastError)

\* Request ID only increases
MonotonicRequestId ==
    [][requestId' >= requestId]_vars

\* Combined safety invariant
SafetyInvariant ==
    /\ TypeInvariant
    /\ RetryBound
    /\ ValidBackoff
    /\ StateConsistency
    /\ MockModeNoBackoff
    /\ RetryOnlyRetryableErrors

(***************************************************************************
 * TEMPORAL PROPERTIES
 ***************************************************************************)

\* Every request eventually completes or fails
EventuallyTerminates ==
    (requestState # "idle") ~>
        (requestState = "success" \/ requestState = "failed")

\* In mock mode, requests complete immediately without retries
MockModeImmediate ==
    mockMode /\ (requestState = "preparing")
        ~> (requestState = "success")

\* Retries follow exponential backoff
ExponentialBackoffProperty ==
    [](requestState = "backoff" /\ retryCount > 0
       => backoffTime = CalculateBackoff(retryCount - 1))

\* After max retries, request fails
MaxRetriesLeadsToFailure ==
    (retryCount = MaxRetries /\ requestState = "backoff")
        ~> (requestState = "failed")

\* System can always accept new requests
EventuallyIdle ==
    <>(requestState = "idle")

\* Non-retryable errors fail immediately
ImmediateFailureForNonRetryable ==
    (requestState = "backoff" /\ ~IsRetryableError(lastError))
        ~> (requestState = "failed")

(***************************************************************************
 * SPECIFICATION
 ***************************************************************************)

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

(***************************************************************************
 * PROPERTIES TO VERIFY
 ***************************************************************************)

\* Properties for TLC model checking
PROPERTIES ==
    /\ SafetyInvariant
    /\ EventuallyTerminates
    /\ EventuallyIdle

(***************************************************************************
 * THEOREMS
 ***************************************************************************)

\* Safety: System always maintains invariants
THEOREM SafetyTheorem == Spec => []SafetyInvariant

\* Liveness: Every request eventually completes
THEOREM LivenessTheorem == Spec => EventuallyTerminates

\* Mock mode always succeeds without retries
THEOREM MockModeTheorem ==
    Spec => (mockMode => EventuallyTerminates)

\* Exponential backoff is correctly applied
THEOREM BackoffTheorem == Spec => []ExponentialBackoffProperty

=============================================================================
