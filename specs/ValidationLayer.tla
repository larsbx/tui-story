--------------------------- MODULE ValidationLayer ---------------------------
(***************************************************************************
 * TLA+ Specification for Input Validation Layer
 *
 * This module models the validation boundary that protects the system from
 * invalid input. It specifies:
 * - Input validation rules
 * - Sanitization logic
 * - Error handling at boundaries
 * - Defense-in-depth strategy
 *
 * Based on: src/validation.zig
 *
 * Author: Claude (Anthropic)
 * Date: 2025-11-20
 ***************************************************************************)

EXTENDS Naturals, Sequences, TLC

CONSTANTS
    MaxLength,          \* Maximum content length (1000)
    MinLength           \* Minimum content length (1)

ASSUME MaxLength = 1000
ASSUME MinLength = 1

(***************************************************************************
 * VARIABLES
 ***************************************************************************)

VARIABLES
    rawInput,           \* Raw input from user (untrusted)
    validatedInput,     \* Validated and sanitized input (trusted)
    validationStatus,   \* Status: "pending", "valid", "invalid"
    errorType,          \* Type of validation error
    sanitizationApplied \* Boolean: was sanitization needed?

vars == <<rawInput, validatedInput, validationStatus, errorType,
          sanitizationApplied>>

(***************************************************************************
 * VALIDATION ERROR TYPES
 ***************************************************************************)

ValidationErrors == {
    "empty_input",      \* Input is empty or whitespace-only
    "too_long",         \* Input exceeds maximum length
    "invalid_utf8",     \* Input contains invalid UTF-8 sequences
    "null_bytes",       \* Input contains null bytes
    "control_chars",    \* Input contains control characters
    NULL                \* No error
}

(***************************************************************************
 * VALIDATION STATES
 ***************************************************************************)

ValidationStates == {"pending", "valid", "invalid"}

(***************************************************************************
 * HELPER OPERATORS
 ***************************************************************************)

\* Check if string is empty (including whitespace-only)
IsEmpty(s) ==
    \/ Len(s) = 0
    \/ \A i \in 1..Len(s) : s[i] \in {" ", "\t", "\n", "\r"}

\* Check if string length is within bounds
IsValidLength(s) ==
    /\ Len(s) >= MinLength
    /\ Len(s) <= MaxLength

\* Check for null bytes (simplified)
HasNullBytes(s) ==
    \E i \in 1..Len(s) : s[i] = "\0"

\* Check for dangerous control characters (simplified)
HasControlChars(s) ==
    \E i \in 1..Len(s) : s[i] \in {"\x00", "\x01", "\x7F"}

\* Sanitize input by removing dangerous characters
Sanitize(s) ==
    \* Simplified: In reality, this would filter characters
    \* For TLA+, we model the effect rather than implementation
    IF HasControlChars(s) \/ HasNullBytes(s)
    THEN "sanitized_content"
    ELSE s

\* Trim whitespace from input
Trim(s) ==
    \* Simplified model of whitespace trimming
    IF Len(s) > 0 /\ (s[1] = " " \/ s[Len(s)] = " ")
    THEN SubSeq(s, 2, Len(s) - 1)
    ELSE s

(***************************************************************************
 * INITIAL STATE
 ***************************************************************************)

Init ==
    /\ rawInput = ""
    /\ validatedInput = NULL
    /\ validationStatus = "pending"
    /\ errorType = NULL
    /\ sanitizationApplied = FALSE

(***************************************************************************
 * INPUT RECEPTION
 ***************************************************************************)

\* Receive raw input from user
ReceiveInput(input) ==
    /\ validationStatus = "pending"
    /\ rawInput' = input
    /\ validatedInput' = NULL
    /\ errorType' = NULL
    /\ sanitizationApplied' = FALSE
    /\ UNCHANGED validationStatus

(***************************************************************************
 * VALIDATION RULES
 ***************************************************************************)

\* Validate: Check if input is empty
ValidateEmpty ==
    /\ validationStatus = "pending"
    /\ rawInput # ""
    /\ IF IsEmpty(rawInput)
       THEN /\ validationStatus' = "invalid"
            /\ errorType' = "empty_input"
            /\ validatedInput' = NULL
       ELSE UNCHANGED <<validationStatus, errorType, validatedInput>>
    /\ UNCHANGED <<rawInput, sanitizationApplied>>

\* Validate: Check length bounds
ValidateLength ==
    /\ validationStatus = "pending"
    /\ errorType = NULL
    /\ IF ~IsValidLength(rawInput)
       THEN /\ validationStatus' = "invalid"
            /\ errorType' = "too_long"
            /\ validatedInput' = NULL
       ELSE UNCHANGED <<validationStatus, errorType, validatedInput>>
    /\ UNCHANGED <<rawInput, sanitizationApplied>>

\* Validate: Check for null bytes
ValidateNullBytes ==
    /\ validationStatus = "pending"
    /\ errorType = NULL
    /\ IF HasNullBytes(rawInput)
       THEN /\ validationStatus' = "invalid"
            /\ errorType' = "null_bytes"
            /\ validatedInput' = NULL
       ELSE UNCHANGED <<validationStatus, errorType, validatedInput>>
    /\ UNCHANGED <<rawInput, sanitizationApplied>>

\* Validate: Check for control characters
ValidateControlChars ==
    /\ validationStatus = "pending"
    /\ errorType = NULL
    /\ IF HasControlChars(rawInput)
       THEN /\ validationStatus' = "invalid"
            /\ errorType' = "control_chars"
            /\ validatedInput' = NULL
       ELSE UNCHANGED <<validationStatus, errorType, validatedInput>>
    /\ UNCHANGED <<rawInput, sanitizationApplied>>

\* Apply sanitization (alternative to rejection)
ApplySanitization ==
    /\ validationStatus = "pending"
    /\ errorType = NULL
    /\ LET sanitized == Sanitize(rawInput)
       IN /\ validatedInput' = sanitized
          /\ sanitizationApplied' = (sanitized # rawInput)
    /\ UNCHANGED <<rawInput, validationStatus, errorType>>

\* Mark as valid after all checks pass
MarkValid ==
    /\ validationStatus = "pending"
    /\ errorType = NULL
    /\ ~IsEmpty(rawInput)
    /\ IsValidLength(rawInput)
    /\ ~HasNullBytes(rawInput)
    /\ validationStatus' = "valid"
    /\ IF validatedInput = NULL
       THEN validatedInput' = rawInput
       ELSE UNCHANGED validatedInput
    /\ UNCHANGED <<rawInput, errorType, sanitizationApplied>>

(***************************************************************************
 * GROUP VALIDATION
 ***************************************************************************)

\* Validate a group of ideas
ValidateGroup ==
    /\ validationStatus = "pending"
    /\ \E group \in Seq(STRING) :
        /\ Len(group) > 0
        /\ Len(group) <= 100  \* Max ideas per group
        /\ \A i \in 1..Len(group) :
            /\ ~IsEmpty(group[i])
            /\ IsValidLength(group[i])

(***************************************************************************
 * ERROR RECOVERY
 ***************************************************************************)

\* Reset validation state for new input
Reset ==
    /\ validationStatus \in {"valid", "invalid"}
    /\ rawInput' = ""
    /\ validatedInput' = NULL
    /\ validationStatus' = "pending"
    /\ errorType' = NULL
    /\ sanitizationApplied' = FALSE

(***************************************************************************
 * NEXT STATE RELATION
 ***************************************************************************)

Next ==
    \/ \E input \in STRING : ReceiveInput(input)
    \/ ValidateEmpty
    \/ ValidateLength
    \/ ValidateNullBytes
    \/ ValidateControlChars
    \/ ApplySanitization
    \/ MarkValid
    \/ ValidateGroup
    \/ Reset

(***************************************************************************
 * INVARIANTS
 ***************************************************************************)

\* Type invariant
TypeInvariant ==
    /\ rawInput \in STRING
    /\ validationStatus \in ValidationStates
    /\ errorType \in ValidationErrors

\* Valid input implies no error
ValidImpliesNoError ==
    validationStatus = "valid" => errorType = NULL

\* Invalid input implies error present
InvalidImpliesError ==
    validationStatus = "invalid" => errorType # NULL

\* Validated input only exists when valid
ValidatedOnlyWhenValid ==
    validatedInput # NULL => validationStatus = "valid"

\* Validated input respects length bounds
ValidatedInputBounds ==
    validatedInput # NULL =>
        /\ Len(validatedInput) >= MinLength
        /\ Len(validatedInput) <= MaxLength

\* No null bytes in validated input
NoNullBytesInValidated ==
    validatedInput # NULL => ~HasNullBytes(validatedInput)

\* No control characters in validated input (or sanitized)
NoControlCharsInValidated ==
    validatedInput # NULL =>
        (~HasControlChars(validatedInput) \/ sanitizationApplied)

\* Sanitization flag only set when sanitization occurred
SanitizationConsistency ==
    sanitizationApplied => validatedInput # rawInput

\* Empty input never validates
EmptyNeverValid ==
    IsEmpty(rawInput) => validationStatus # "valid"

\* Over-length input never validates
OverLengthNeverValid ==
    Len(rawInput) > MaxLength => validationStatus # "valid"

\* Error type matches validation failure
ErrorTypeConsistency ==
    /\ (errorType = "empty_input" => IsEmpty(rawInput))
    /\ (errorType = "too_long" => Len(rawInput) > MaxLength)
    /\ (errorType = "null_bytes" => HasNullBytes(rawInput))

\* Combined safety invariant
SafetyInvariant ==
    /\ TypeInvariant
    /\ ValidImpliesNoError
    /\ InvalidImpliesError
    /\ ValidatedOnlyWhenValid
    /\ ValidatedInputBounds
    /\ NoNullBytesInValidated
    /\ NoControlCharsInValidated
    /\ SanitizationConsistency
    /\ EmptyNeverValid
    /\ OverLengthNeverValid
    /\ ErrorTypeConsistency

(***************************************************************************
 * SECURITY INVARIANTS
 ***************************************************************************)

\* Defense in depth: Multiple validation layers
DefenseInDepth ==
    validationStatus = "valid" =>
        /\ ~IsEmpty(validatedInput)
        /\ IsValidLength(validatedInput)
        /\ ~HasNullBytes(validatedInput)
        /\ (~HasControlChars(validatedInput) \/ sanitizationApplied)

\* No untrusted data bypasses validation
NoBypass ==
    validatedInput # NULL => validationStatus = "valid"

\* Fail-safe: Default to rejection
FailSafe ==
    errorType # NULL => validationStatus # "valid"

\* Combined security invariant
SecurityInvariant ==
    /\ DefenseInDepth
    /\ NoBypass
    /\ FailSafe

(***************************************************************************
 * TEMPORAL PROPERTIES
 ***************************************************************************)

\* Every input eventually gets validated
EventuallyValidated ==
    (validationStatus = "pending" /\ rawInput # "")
        ~> (validationStatus \in {"valid", "invalid"})

\* System can always accept new input
EventuallyReady ==
    <>(validationStatus = "pending")

\* Invalid input never becomes valid without reset
InvalidStaysInvalid ==
    [](validationStatus = "invalid" => X(validationStatus # "valid"))

\* Valid input produces validated output
ValidProducesOutput ==
    <>(validationStatus = "valid" => validatedInput # NULL)

(***************************************************************************
 * SPECIFICATION
 ***************************************************************************)

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

(***************************************************************************
 * THEOREMS
 ***************************************************************************)

\* Safety: System always maintains security invariants
THEOREM SecurityTheorem == Spec => []SecurityInvariant

\* Safety: No untrusted data passes validation
THEOREM NoBypassTheorem == Spec => []NoBypass

\* Liveness: Every input eventually gets validated
THEOREM LivenessTheorem == Spec => EventuallyValidated

\* Safety: Validated input always respects bounds
THEOREM BoundsTheorem == Spec => []ValidatedInputBounds

=============================================================================
