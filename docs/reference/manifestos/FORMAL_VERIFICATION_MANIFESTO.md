# Formal Verification Manifesto: 16 Foundational Principles

**Version**: 1.1
**Classification**: Public
**License**: CC0 - Public Domain
**Standards**: Common Criteria, DO-178C, IEC 61508
**References**: Software Foundations, CPDT, Types and Programming Languages

---

## Quick Navigation

- **New to formal methods?** → Start with [Learning Paths](#learning-paths) and [Decision Tree](#decision-tree-tool-selection)
- **Evaluating tools?** → See [Decision Tree](#decision-tree-tool-selection) and [Verification Spectrum](#verification-spectrum)
- **Implementing verification?** → Review [Common Pitfalls](#common-pitfalls) and [Incremental Formalization](#xvi-incremental-formalization)
- **Executive summary** → See [EXECUTIVE_SUMMARY.md](./EXECUTIVE_SUMMARY.md)

---

## I. Specification as Foundation

**Formal specification precedes implementation; properties stated mathematically; correctness defined rigorously before construction.**

Informal requirements insufficient. Specifications express precise invariants, preconditions, postconditions. Mathematical notation eliminates ambiguity. Theorem proving validates specification consistency before code written.

```coq
(* Specification precedes implementation *)
Definition sorted {A : Type} (le : A → A → Prop) (l : list A) : Prop :=
  ∀ i j, i < j < length l → le (nth i l) (nth j l).

Theorem sorted_preserved_by_insert :
  ∀ (x : A) (l : list A),
    sorted le l → sorted le (insert x l).
```

### Specification Methods

- **Formal methods**: Z notation, TLA+, Alloy, VDM for specification
- **Refinement**: high-level spec → executable implementation through verified steps
- **Specification review**: theorem prover checks consistency, completeness
- **Contradiction detection**: impossible specs rejected at specification phase

### Specification Validation

**Critical Challenge**: How do we know the specification itself is correct?

Specifications can contain bugs even when mathematically consistent. Validate specifications through:

1. **Executable Specifications**: Run spec against test cases
   ```alloy
   -- Alloy: bounded model checking finds spec bugs
   sig Node { edges: set Node }

   pred acyclic { no n: Node | n in n.^edges }

   run acyclic for 5  -- Find instances satisfying spec
   check acyclic for 10  -- Search for counterexamples
   ```

2. **Property-Based Testing**: QuickCheck validates spec sanity
   ```haskell
   -- Validate specification properties
   prop_sortPreservesLength :: [Int] -> Bool
   prop_sortPreservesLength xs = length (sort xs) == length xs

   prop_sortedOutput :: [Int] -> Bool
   prop_sortedOutput xs = isSorted (sort xs)
   ```

3. **Lightweight Model Checking**: Alloy, TLA+ model checker explore spec behavior
4. **Specification Reviews**: Multi-disciplinary teams review specs
5. **Incremental Specification**: Start abstract, refine, validate each step

**Example**: seL4 specification required multiple revisions after implementation revealed ambiguities. Specification is iterative, not one-shot.

---

## II. Types as Propositions

**Curry-Howard correspondence: types are theorems, programs are proofs; well-typed programs provably correct.**

Every type encodes logical proposition. Program inhabiting type constitutes proof. Type checker verifies proof validity. Dependent types express arbitrarily complex properties.

```agda
-- Type expresses specification
-- Implementation proves specification
reverse-involutive : ∀ {A : Set} (xs : List A)
                   → reverse (reverse xs) ≡ xs
reverse-involutive []       = refl
reverse-involutive (x ∷ xs) =
  begin
    reverse (reverse (x ∷ xs))
  ≡⟨ cong reverse (reverse-cons x xs) ⟩
    reverse (reverse xs ++ [ x ])
  ≡⟨ reverse-concat (reverse xs) [ x ] ⟩
    [ x ] ++ reverse (reverse xs)
  ≡⟨ cong ([ x ] ++_) (reverse-involutive xs) ⟩
    [ x ] ++ xs
  ≡⟨ cons-append x xs ⟩
    x ∷ xs
  ∎
```

### Explained: Curry-Howard Correspondence

This type signature is a **THEOREM**:
> "For all types A and lists xs of type A, reversing twice gives back the original list"

The proof (implementation) proceeds by **induction**:
- **Base case**: empty list `[]` trivially reverses to itself (`refl`)
- **Inductive case**: assume theorem holds for `xs`, prove it for `(x ∷ xs)` using associativity of `++`

**Key Insight**: The program **is** the proof. If it type-checks, the theorem is proved.

### Applications

- **Dependent types**: Agda, Idris, Coq, Lean
- **Propositions as Types (PAT)**: `A → B` ≡ "A implies B"
- **Proof terms**: programs are constructive proofs
- **Type refinement**: `{x : ℕ | x > 0}` encodes positive integers
- **Proof irrelevance**: runtime erases proofs, zero overhead

---

## III. Totality & Termination

**All functions total; domain and codomain explicit; termination structurally proven or annotated.**

Partial functions rejected. Infinite loops impossible. Structural recursion or well-founded recursion. Totality checker enforces termination. Divergence explicitly marked in type.

```idris
-- Totality checking enforced
total
div : (n : Nat) → (m : Nat) → {auto ok : IsSucc m} → Nat
div n Z     {ok = ItIsSucc} impossible
div n (S k) = divHelper n (S k) (S k)
  where
    total
    divHelper : Nat → Nat → Nat → Nat
    divHelper Z        _ _ = Z
    divHelper (S n)    d Z = S (divHelper n d d)
    divHelper (S n)    d (S k) = divHelper n d k

-- Explicit partiality when unavoidable
partial
readFile : String → IO String
```

### Common Mistake: Non-Total Functions

```idris
-- WRONG: Non-total function (missing case)
head : List a -> a
head (x :: xs) = x
-- Missing case: head [] = ???
-- Runtime crash possible!

-- CORRECT: Total function with dependent type
head : (xs : List a) -> {auto ok : NonEmpty xs} -> a
head (x :: xs) = x
-- Type system prevents calling head on empty list
```

### Termination Techniques

- **Structural recursion**: argument syntactically smaller
- **Well-founded recursion**: measure decreases w.r.t. well-founded relation
- **Sized types**: track structural decrease through type system
- **Productivity for codata**: dual of termination for infinite structures
- **Turing-incompleteness acceptable**: totality > arbitrary computation

---

## IV. Refinement Types

**Types enriched with logical predicates; SMT solvers verify constraints; impossibility encoded statically.**

Base types augmented with refinement predicates. Liquid types enable inference. SMT integration automates proof obligations. Invalid states unrepresentable.

```fstar
// Refinement types in F*
type nat = x:int{x >= 0}
type pos = x:int{x > 0}
type even = x:int{x % 2 = 0}

val div : nat → pos → nat
let div n d = n / d  // SMT proves d ≠ 0, no runtime check

type vector (a:Type) (n:nat) =
  l:list a{length l = n}

val head : ∀ (a:Type) (n:pos). vector a n → a
let head #a #n v = match v with
  | hd::_ → hd
  // Pattern match coverage checker proves non-empty
```

### Applications

- **Liquid Types**: automatic refinement inference via abstract interpretation
- **SMT solvers**: Z3, CVC4, Yices prove refinement predicates
- **Decidable fragments**: linear arithmetic, equality, uninterpreted functions
- **Refinement composition**: intersection types combine multiple predicates
- **Contract verification**: preconditions, postconditions in type signatures

---

## V. Separation Logic

**Spatial reasoning about mutable state; ownership tracked; aliasing prevented; memory safety proven.**

Heap described using separation conjunction (∗). Ownership explicit. Frame rule enables local reasoning. No garbage collection proofs required when ownership linear.

```
// Hoare triple with separation logic
{emp}
  let x = alloc(42)
{∃ℓ. x ↦ 42}

{x ↦ v ∗ y ↦ w}
  swap(x, y)
{x ↦ w ∗ y ↦ v}

// Frame rule: local reasoning
{P} C {Q}
────────────────────  (modifies(C) ∩ FV(R) = ∅)
{P ∗ R} C {Q ∗ R}
```

### Explained: Separation Logic

**Key Concepts**:
- **Separation conjunction (∗)**: `P ∗ Q` means P and Q hold for **disjoint** heap regions
- **Points-to predicate (↦)**: `x ↦ v` means location `x` contains value `v` and we **own** it
- **Frame rule**: If code C only modifies heap described by P, then unmentioned heap R is unchanged

**Why This Matters**: Prevents aliasing bugs. If `x ↦ v ∗ y ↦ w`, then `x ≠ y` is **guaranteed**.

### Tools and Extensions

- **Separation conjunction (∗)**: non-overlapping heap regions
- **Points-to predicate (↦)**: ownership of memory location
- **Magic wand (−∗)**: "if I give you P, you give me Q"
- **Tools**: Iris (Coq), VeriFast, Viper, Steel (F*)
- **Concurrent separation logic**: reasoning about shared-memory concurrency

---

## VI. Proof Irrelevance & Extraction

**Proofs erased at runtime; verified code achieves production-grade performance; soundness without prohibitive penalty.**

Proof terms exist at compile time only. Extraction eliminates proof content. Computational content preserved. Verified programs achieve performance competitive with conventional implementations.

```coq
(* Proof-carrying code *)
Definition safe_head {A : Type} (l : list A) (H : l ≠ []) : A :=
  match l as l' return (l' ≠ [] → A) with
  | []      => λ H, match H eq_refl with end  (* Impossible case *)
  | x :: _  => λ _, x
  end H.

(* Extraction to OCaml removes proof H *)
Extraction safe_head.
(* ⟹ let safe_head = function
        | []     -> assert false  (* Unreachable *)
        | x :: _ -> x
*)
```

### Performance Reality Check

**Updated Guidance**: Verified programs achieve production-grade performance with caveats:

- **CompCert C compiler**: ~8-10% slower than GCC -O3 on some benchmarks, but competitive
- **Extracted OCaml from Coq**: Can be inefficient with naïve data structures; manual optimization may be needed
- **CakeML**: Performance gaps vs. production compilers exist but are narrowing
- **Performance-critical sections**: Use verified assembly (Vale) or verified low-level code (Jasmin, Low*) to match hand-optimized code
- **Overall**: Extraction overhead acceptable for most applications; critical paths require specialized approaches

### Extraction Techniques

- **Prop vs. Set/Type**: computational vs. logical content
- **Extraction languages**: OCaml, Haskell, Scheme, Rust
- **Proof erasure**: `{x : A | P x}` extracts to `A`
- **Axioms require care**: proof-relevant axioms prevent extraction
- **Verified compilers**: CompCert, CakeML prove compilation preserves semantics

---

## VII. Abstract Interpretation

**Static analysis via abstract domains; approximate program behavior; soundness guaranteed; false positives acceptable.**

Concrete semantics abstracted to finite domains. Analysis computes over-approximation. Soundness: no false negatives. Precision: minimize false positives.

```
// Interval analysis example
x := [1, 10]     // x ∈ {1,2,...,10}
y := [5, 15]     // y ∈ {5,6,...,15}
z := x + y       // z ∈ [6, 25]  (sound over-approximation)

// Sign analysis
{x > 0, y > 0} ⊢ x + y ∈ (+)
{x > 0, y < 0} ⊢ x + y ∈ (⊤)  // unknown sign

// Null pointer analysis
{p ≠ null} *p {safe}
{p = null}  *p {unsafe}
```

### Abstract Domains and Tools

- **Abstract domains**: intervals, octagons, polyhedra, symbolic values
- **Widening/narrowing**: ensure termination for loops
- **Galois connection**: abstraction/concretization functions preserve ordering
- **Tools**: Astrée, Polyspace, Infer, Coverity
- **Soundness vs. completeness trade-off**: over-approximate for safety

---

## VIII. Model Checking

**Exhaustive state space exploration; temporal properties verified; counterexamples generated automatically.**

Finite state systems explored completely. Temporal logic (LTL, CTL) expresses properties. Model checker finds violations. Counterexample trace guides debugging.

```tla
---- MODULE BankAccount ----
EXTENDS Integers
VARIABLE balance

Init ≜ balance = 0

Deposit(amount) ≜
  ∧ amount > 0
  ∧ balance' = balance + amount

Withdraw(amount) ≜
  ∧ amount > 0
  ∧ balance ≥ amount
  ∧ balance' = balance - amount

Next ≜ ∃ amount ∈ Int : Deposit(amount) ∨ Withdraw(amount)

TypeInvariant ≜ balance ≥ 0  (* Never negative *)

Spec ≜ Init ∧ □[Next]_balance ∧ TypeInvariant
============================
```

### Temporal Logic and Tools

- **Temporal logic**: LTL (linear time), CTL (computation tree)
- **Safety properties**: "bad thing never happens" (□¬Bad)
- **Liveness properties**: "good thing eventually happens" (◇Good)
- **Bounded model checking**: explore states up to depth k
- **Symbolic model checking**: BDDs, SAT/SMT for compact representation
- **Tools**: TLA+, SPIN, NuSMV, UPPAAL, PRISM

---

## IX. Proof Automation

**Tactics and proof search minimize manual proof; decidable fragments fully automated; interactive when necessary.**

Proof assistants provide automation. Decidable theories fully automatic. SMT integration for arithmetic, arrays. Heuristic search for general theorems. Manual proof for complex reasoning.

```coq
(* Automation levels *)

(* Level 1: Trivial - fully automatic *)
Theorem add_comm : ∀ n m, n + m = m + n.
Proof. intros. ring. Qed.

(* Level 2: Automatic with hints *)
Theorem sorted_tail : ∀ x xs, sorted (x::xs) → sorted xs.
Proof. intros. inversion H. auto. Qed.

(* Level 3: Semi-automatic - guided search *)
Theorem rev_involutive : ∀ (l : list nat), rev (rev l) = l.
Proof.
  induction l as [| n l' IHl'].
  - reflexivity.
  - simpl. rewrite rev_app_distr. rewrite IHl'.
    reflexivity.
Qed.

(* Level 4: Manual - complex proof *)
Theorem church_rosser : ∀ t t1 t2,
  t ⟹* t1 → t ⟹* t2 →
  ∃ t', t1 ⟹* t' ∧ t2 ⟹* t'.
Proof. (* 50+ lines of careful reasoning *) Admitted.
```

### Automation Techniques

- **Tactics**: `auto`, `intuition`, `omega`, `lia`, `ring`, `field`
- **Hammer tools**: sledgehammer (Isabelle), hammer (Coq) call ATP/SMT
- **Proof by reflection**: verified decision procedure in language
- **Ltac/Mtac**: metaprogramming proof automation
- **Neural theorem proving**: ML-guided search (GPT-f, Thor)

---

## X. Symbolic Execution

**Explore execution paths symbolically; path conditions as formulas; constraint solving finds inputs exposing bugs.**

Variables symbolic rather than concrete. Path conditions accumulated. SMT solver determines feasibility. Generates test inputs triggering each path.

```python
# Symbolic execution example
def absolute(x):
    if x >= 0:
        return x
    else:
        return -x

# Symbolic execution generates:
# Path 1: x ≥ 0  ⟹ return x      (constraint: x ≥ 0)
# Path 2: x < 0  ⟹ return -x     (constraint: x < 0)

# Concrete inputs satisfying each path:
# Path 1: x = 5
# Path 2: x = -3
```

### Path Explosion Mitigation

**Challenge**: Exponential paths w.r.t. branches.

**Mitigation Strategies**:
1. **Selective symbolic execution**: Only critical paths
2. **Compositional symbolic execution**: Function summaries reused
3. **Under-constrained symbolic execution**: Missing callees modeled abstractly
4. **Lazy initialization**: Objects created on-demand
5. **Path merging**: Combine similar paths
6. **Pruning**: Eliminate infeasible paths early

### Tools and Techniques

- **Concolic testing**: concrete + symbolic execution hybrid
- **Tools**: KLEE, S2E, angr, Manticore, SAGE
- **Bounded execution**: explore up to depth limit

---

## XI. Verified Compilation

**Compilation preserves semantics; compiler correctness proven; source-level reasoning about binary behavior.**

Compiler verification proves: if source satisfies spec, binary satisfies spec. Source reasoning sufficient. Optimizations preserve meaning. No compiler bugs introduce vulnerabilities.

```
Source ⟹[compiler]⟹ Binary
  ↓ semantics           ↓ semantics
Observable              Observable
Behavior    ⟹[≡]⟹      Behavior

Theorem compiler_correctness:
  ∀ (src : Source) (bin : Binary),
    compile src = Some bin →
    ∀ (input : Input),
      behavior src input ≡ behavior bin input
```

### Verified Compilers in Practice

- **CompCert**: verified C compiler, proved correct in Coq
- **CakeML**: verified ML compiler, bootstrapped, proved end-to-end
- **SeL4**: verified OS microkernel, full functional correctness
- **Vellvm**: verified LLVM transformations
- **Translation validation**: verify each compilation run, not compiler itself

---

## XII. Contract-Based Design

**Preconditions, postconditions, invariants as executable contracts; runtime checking in development; static proof in production.**

DbC (Design by Contract) formalized. Contracts as specifications. Dynamic checking during development. Static verification eliminates checks in production.

```ada
-- Ada contracts
function Sqrt(X : Float) return Float
  with Pre  => X >= 0.0,
       Post => Sqrt'Result >= 0.0 and then
               abs(Sqrt'Result * Sqrt'Result - X) < 0.001;

procedure Swap(X, Y : in out Integer)
  with Post => X = Y'Old and Y = X'Old;

-- Loop invariants
procedure Binary_Search(A : Array; Key : Integer; Index : out Integer)
  with Pre => Is_Sorted(A)
is
  Low, High, Mid : Integer;
begin
  Low := A'First; High := A'Last;
  loop
    pragma Loop_Invariant
      (Low in A'Range and High in A'Range);
    pragma Loop_Invariant
      (for all I in A'First .. Low-1 => A(I) < Key);
    pragma Loop_Invariant
      (for all I in High+1 .. A'Last => A(I) > Key);

    exit when Low > High;
    Mid := Low + (High - Low) / 2;
    if A(Mid) < Key then
      Low := Mid + 1;
    elsif A(Mid) > Key then
      High := Mid - 1;
    else
      Index := Mid; return;
    end if;
  end loop;
end Binary_Search;
```

### Contract Languages and Tools

- **Eiffel**: original DbC language
- **SPARK Ada**: contracts + static proof
- **Dafny**: automatic verification of contracts
- **JML (Java Modeling Language)**: contracts for Java
- **Runtime assertion checking**: development/testing mode
- **Static verification**: production mode, proofs discharged

---

## XIII. Correct-by-Construction

**Derive implementation from specification through verified refinement; each step proven correct.**

Top-down development: specification → design → implementation. Each refinement step proven correct. Composition of correct steps yields correct system. Debugging minimized through construction process.

```
Abstract Specification
  ↓ [refinement + proof]
High-Level Design
  ↓ [refinement + proof]
Detailed Design
  ↓ [refinement + proof]
Implementation

Event-B refinement example:
MACHINE M0  // Abstract
  VARIABLES x
  INVARIANT x ∈ ℕ
  INITIALISATION x := 0
  EVENTS
    increment = x := x + 1
END

REFINEMENT M1  // Concrete
  VARIABLES count, step
  INVARIANT x = count * step
  REFINES increment
    WHEN count < 100
    THEN count := count + 1
  END
```

### Reality Check: Correct-by-Construction Limits

**Important**: While correct-by-construction minimizes debugging, it does not eliminate it entirely:

- **Specification changes**: Requirements evolve, requiring proof updates
- **Proof maintenance**: Refinement proofs can be brittle
- **Human error**: Incorrect refinement steps require debugging
- **Incomplete automation**: Some proofs require manual intervention

**Best Practice**: Correct-by-construction reduces debugging burden significantly but requires iterative refinement of both specs and proofs.

### Refinement Methods

- **Refinement calculus**: laws for transforming specifications into code
- **B-Method, Event-B**: refinement-based development
- **Data refinement**: abstract data structure → concrete implementation
- **Operation refinement**: atomic operation → compound operations
- **Proof obligations**: discharged per refinement step

---

## XIV. Concurrency Verification

**Linearizability, deadlock-freedom, race-freedom proven; concurrent algorithms verified correct.**

Shared-memory concurrency: separation logic, rely-guarantee. Message-passing: session types, process calculi. Lock-free algorithms: linearizability proofs.

```
// Concurrent separation logic
{emp}
  let x = alloc(0) in
  {x ↦ 0}
  parallel
    {x ↦ 0}
      [x] := 1
    {x ↦ 1}
  ||
    {x ↦ 1}
      n := ![x]
    {x ↦ 1 ∗ n = 1}
  {x ↦ 1 ∗ n = 1}

// Session types for communication
type Protocol = !Int . ?Bool . end
send : Protocol → Int → ?Bool . end
recv : ?Bool . end → Bool × end
```

### Explained: Concurrent Separation Logic

**Challenge**: In concurrent programs, threads can interfere with each other's heap.

**Solution**: Track ownership precisely. If thread A owns `x ↦ v`, thread B cannot access `x`.

**Transfer**: Ownership can be transferred between threads via synchronization.

### Distributed Systems Verification

**Specific Challenges**:
- **Network partitions**: Messages delayed or lost
- **Byzantine faults**: Malicious nodes
- **Eventual consistency**: CAP theorem trade-offs
- **Consensus protocols**: Raft, Paxos correctness

**Verification Approaches**:

1. **TLA+ for Distributed Systems**:
   ```tla
   ---- MODULE Raft ----
   (* Leader election, log replication verified *)

   Safety ==
     /\ ElectionSafety    (* At most one leader per term *)
     /\ LogMatching       (* Logs on different servers consistent *)
     /\ LeaderCompleteness (* Committed entries persist *)

   Liveness ==
     /\ EventualLeaderElection
     /\ EventualConsensus
   ============================
   ```

2. **IVy**: Inductive invariants for distributed protocols
3. **Verdi**: Verified distributed systems in Coq (Raft implementation)
4. **DistAlgo**: Executable specifications for distributed algorithms

**Industrial Adoption**:
- AWS uses TLA+ for S3, DynamoDB, EC2
- Azure Cosmos DB verified with TLA+
- MongoDB verified Raft implementation

### Concurrency Tools and Methods

- **Concurrent separation logic**: Iris, Viper, TaDA
- **Rely-guarantee reasoning**: assume-guarantee for concurrency
- **Linearizability**: concurrent operations appear atomic
- **Session types**: communication protocols in types
- **Process calculi**: π-calculus, CSP for message-passing verification
- **Model checking**: SPIN for protocol verification

---

## XV. Verified Cryptography

**Cryptographic implementations proven functionally correct, constant-time, side-channel resistant.**

Functional correctness: encryption/decryption roundtrip. Constant-time: execution independent of secrets. Memory safety: no buffer overflows. Cryptographic security requires separate proof frameworks.

```fstar
// Verified cryptography in F*
val aes_encrypt :
  key:lbytes 16 →
  plaintext:lbytes 16 →
  Pure (ciphertext:lbytes 16)
    (requires True)
    (ensures λ ct →
      aes_decrypt key ct == plaintext ∧
      is_constant_time aes_encrypt)

// Constant-time verification
val select_constant_time (b:bool) (x y:uint32) :
  Pure uint32
    (requires True)
    (ensures λ z →
      z == (if b then x else y) ∧
      execution_time_independent_of b)
```

### Cryptographic Security: The Reality

**Current State**: No single tool proves both functional correctness AND cryptographic security end-to-end.

**What Can Be Proven**:
- **HACL*/EverCrypt**: Functional correctness + constant-time execution + memory safety
- **Vale**: Verified assembly for performance-critical primitives
- **EasyCrypt/CryptoVerif**: Cryptographic security (IND-CPA, IND-CCA2) in game-based models

**The Gap**: Functional correctness frameworks (F*) and cryptographic security frameworks (EasyCrypt) are not yet integrated.

**Best Practice**:
1. Prove functional correctness + constant-time in F*/Vale
2. Separately prove cryptographic security in EasyCrypt
3. Manual reasoning to connect the two

**Future Work**: Unified frameworks combining both are active research areas.

### Verified Crypto Tools

- **HACL***: verified crypto library (TLS, Signal protocol)
- **EverCrypt**: verified crypto with agile algorithms
- **Vale**: verified assembly for performance-critical crypto
- **Constant-time verification**: CT-Wasm, dudect, ctgrind
- **Side-channel resistance**: cache-timing, power analysis
- **Cryptographic security proofs**: CryptoVerif, EasyCrypt

---

## XVI. Incremental Formalization

**Start with lightweight methods; progressively increase rigor; formalize critical components first.**

**New Principle**: Full formal verification is expensive. Adopt formal methods incrementally based on component criticality and team expertise.

### Incremental Adoption Pathway

```
Level 0: Manual Testing
├─ Unit tests, integration tests
└─ Code review

Level 1: Type Safety
├─ Strong static typing (Rust, TypeScript, OCaml)
├─ Algebraic data types
└─ Pattern matching exhaustiveness

Level 2: Lightweight Static Analysis
├─ Linters (clippy, ESLint)
├─ Null/undefined checkers
└─ Memory safety (Rust borrow checker, AddressSanitizer)

Level 3: Contracts (Runtime → Static)
├─ Runtime assertions (DbC)
├─ Precondition/postcondition checking
└─ Gradual migration to static verification (Dafny, SPARK)

Level 4: Refinement Types
├─ Liquid Haskell for pure functions
├─ F* for critical algorithms
└─ SMT-based verification

Level 5: Dependent Types & Proof Assistants
├─ Coq/Lean for critical components only
├─ Interactive theorem proving
└─ Full functional correctness proofs

Level 6: End-to-End Verification
├─ Verified compilation (CompCert, CakeML)
├─ Verified runtime (seL4)
└─ Cryptographic security proofs (EasyCrypt)
```

### Strategic Formalization

**Prioritize Verification By**:
1. **Criticality**: Safety-critical, security-critical components first
2. **Stability**: Mature APIs benefit more than rapidly changing code
3. **Complexity**: Complex algorithms have higher bug risk
4. **Reusability**: Standard libraries, crypto primitives used widely

**Example Allocation** (typical web application):
- **Level 5-6**: Authentication, authorization, crypto
- **Level 3-4**: Database layer, API contracts
- **Level 1-2**: UI components, presentation logic
- **Level 0**: Prototypes, experimental features

### Practical Guidance

**Start Simple**:
- Week 1: Add type annotations (TypeScript, mypy)
- Week 2: Enable strict null checking
- Month 1: Add contracts to critical functions
- Month 2: Verify one critical function with Dafny/F*
- Quarter 1: Establish verification for all new security-critical code

**Maintain Momentum**:
- Track verification coverage metrics
- Celebrate verification milestones
- Build internal expertise through training
- Share proof patterns across team

---

## Common Pitfalls

### Pitfall 1: Over-Specification

**Problem**: Spec too strong, implementation impossible or overconstrained.

**Example**:
```coq
(* BAD: Over-specified sort *)
Definition sort_overspec (l : list nat) : list nat :=
  (* Requires specific algorithm, not just sorted output *)
  insertion_sort l.

(* GOOD: Relational spec allows any correct sort *)
Definition is_sorted_permutation (input output : list nat) : Prop :=
  sorted output ∧ permutation input output.
```

**Solution**: Use relational specs. Allow nondeterminism when multiple valid outputs exist.

---

### Pitfall 2: Proof Automation Over-Reliance

**Problem**: `auto` works in development, mysteriously breaks later.

**Example**:
```coq
(* BAD: Magic automation *)
Theorem my_theorem : ∀ x y, P x y.
Proof. auto. Qed.  (* Why did this work? *)

(* GOOD: Explicit steps *)
Theorem my_theorem : ∀ x y, P x y.
Proof.
  intros x y.
  unfold P.
  destruct x; auto.
Qed.
```

**Solution**: Understand which tactics succeed. Use `info_auto` to see proof terms. Prefer explicit reasoning for maintainability.

---

### Pitfall 3: Axiom Abuse

**Problem**: Adding axioms for convenience breaks consistency or extraction.

**Example**:
```coq
(* DANGEROUS: Breaking constructivity *)
Axiom excluded_middle : ∀ P, P ∨ ¬P.

(* SAFE: Use type classes for optional classical reasoning *)
Require Import Classical.
Theorem my_classical_theorem : P ∨ ¬P.
Proof. apply classic. Qed.
```

**Solution**: Minimize axioms. Use type classes for optional assumptions. Verify axiom consistency.

---

### Pitfall 4: Ignoring Proof Maintenance

**Problem**: Proofs break when implementation changes. Accumulates proof debt.

**Example**: Refactoring a function requires updating 50+ dependent proofs.

**Solution**:
- Design for proof stability (abstraction barriers)
- Modular proofs with clear interfaces
- Budget time for proof maintenance
- Consider abandoning proofs for frequently changing code

---

### Pitfall 5: Verification Without Validation

**Problem**: Perfectly proving the wrong specification.

**Example**: Formally verified sorting algorithm that's too slow for production.

**Solution**:
- Validate specifications with stakeholders
- Executable specs + property-based testing
- Performance benchmarks alongside correctness proofs
- Iterative spec refinement

---

## Learning Paths

### For Practitioners (30-Day Quickstart)

**Goal**: Verify one function completely; understand cost-benefit trade-offs.

**Week 1: Foundations** (10 hours)
- Read: Software Foundations Volume 1, chapters 1-5
- Install: Coq + VSCode with Coq plugin
- Practice: Basic tactics (`intros`, `simpl`, `reflexivity`, `induction`)

**Week 2: Automatic Verification** (10 hours)
- Read: Dafny tutorial (https://dafny.org/dafny/OnlineTutorial/guide)
- Tool: Install Dafny
- Practice: Verify 3 functions (sorting, binary search, linked list operations)

**Week 3: Apply to Real Code** (15 hours)
- Choose: One critical function in your codebase
- Specify: Write formal preconditions, postconditions
- Verify: Use Dafny or SPARK Ada
- Reflect: Was verification effort worth it?

**Week 4: Model Checking** (10 hours)
- Read: TLA+ Hyperbook (learntla.com)
- Tool: Install TLA+ Toolbox
- Practice: Model a distributed protocol from your system
- Run: TLC model checker, find bugs

**Outcome**: You can now evaluate formal methods for your projects.

---

### For Researchers (3-Month Deep Dive)

**Goal**: Contribute to formal verification research; prove complex theorems.

**Month 1: Advanced Proof Techniques**
- Read: CPDT (Certified Programming with Dependent Types)
- Topics: Proof by reflection, dependent types, universe polymorphism
- Project: Verify a compiler pass or interpreter

**Month 2: Concurrent Separation Logic**
- Read: Iris tutorial (https://iris-project.org/tutorial-material.html)
- Topics: Higher-order separation logic, invariants, ghost state
- Project: Verify a concurrent data structure

**Month 3: Domain-Specific**
- Read: 5 recent papers in your domain (POPL, CAV, PLDI)
- Replicate: One proof from a paper
- Extend: Add new feature or theorem
- Publish: Workshop paper or arXiv preprint

**Outcome**: Ready for PhD research in formal methods.

---

### For Engineering Managers (1-Day Overview)

**Goal**: Decide whether formal methods fit your organization.

**Morning (4 hours): Understanding**
- Read: This manifesto's Executive Summary
- Read: "Why Amazon Chose TLA+" (https://lamport.azurewebsites.net/tla/amazon.html)
- Read: "How We Verified seL4" (https://sel4.systems/About/seL4-whitepaper.pdf)

**Afternoon (4 hours): Decision Framework**
- Assess: Which components are safety/security critical?
- Calculate: Cost of bugs vs. cost of verification (see Cost-Benefit Analysis)
- Decide: Start with Level 1-2 (types + static analysis) or jump to Level 3 (contracts)?
- Plan: Training budget, tool licenses, timeline

**Outcome**: Informed decision on formal methods adoption.

---

## Decision Tree: Tool Selection

```
┌─ What are you verifying? ─────────────────────────────────────┐
│                                                                │
├─ Memory safety only?                                          │
│  ├─ Existing C/C++ code? ─→ AddressSanitizer, Valgrind       │
│  ├─ New code? ─→ Rust type system, borrow checker            │
│  └─ Large codebase? ─→ Infer, Coverity (abstract interp)     │
│                                                                │
├─ Functional correctness (pure functions)?                     │
│  ├─ Automatic verification? ─→ Dafny, F* with SMT            │
│  ├─ Haskell code? ─→ Liquid Haskell (refinement types)       │
│  └─ Complex proofs? ─→ Coq, Lean (interactive)               │
│                                                                │
├─ Functional correctness (stateful/imperative)?                │
│  ├─ Ada code? ─→ SPARK Ada                                   │
│  ├─ C code? ─→ Frama-C, VeriFast                             │
│  ├─ Automatic? ─→ Dafny                                      │
│  └─ Strongest guarantees? ─→ Coq + separation logic (Iris)   │
│                                                                │
├─ Concurrency correctness?                                     │
│  ├─ Lock-based shared memory? ─→ Iris (Coq), Viper           │
│  ├─ Lock-free algorithms? ─→ Iris + linearizability proofs   │
│  ├─ Message-passing? ─→ Session types (Rust, multiparty)     │
│  └─ Data race detection only? ─→ ThreadSanitizer, Helgrind   │
│                                                                │
├─ Distributed systems protocol?                                │
│  ├─ Design phase? ─→ TLA+ (model checking)                   │
│  ├─ Implementation? ─→ Verdi (Coq), IVy                      │
│  └─ Testing? ─→ Jepsen, TLA+ with PlusCal                    │
│                                                                │
├─ Cryptographic implementation?                                │
│  ├─ C code? ─→ HACL* (F*) + Vale (assembly)                  │
│  ├─ Constant-time needed? ─→ CT-Wasm, FaCT                   │
│  ├─ Protocol security? ─→ EasyCrypt, CryptoVerif              │
│  └─ Side-channels? ─→ ctgrind, dudect (testing)              │
│                                                                │
├─ Compiler/interpreter correctness?                            │
│  ├─ Small language? ─→ Coq, define semantics + prove         │
│  ├─ C compiler? ─→ CompCert (verified), Vellvm (LLVM)        │
│  ├─ ML compiler? ─→ CakeML (end-to-end verified)             │
│  └─ JIT compiler? ─→ Translation validation per run          │
│                                                                │
├─ Operating system/kernel?                                     │
│  ├─ Microkernel? ─→ seL4 approach (Isabelle/HOL)             │
│  ├─ File system? ─→ FSCQ, Cogent                             │
│  └─ Device drivers? ─→ Cogent, separation logic              │
│                                                                │
└─ Quick bug finding (not full proof)?                          │
   ├─ Symbolic execution ─→ KLEE, angr                          │
   ├─ Model checking (bounded) ─→ CBMC, ESBMC                   │
   ├─ Fuzzing ─→ AFL, libFuzzer                                 │
   └─ Static analysis ─→ Infer, Clang Static Analyzer          │
                                                                 │
────────────────────────────────────────────────────────────────┘

Decision Factors:
- Automation desired: Dafny, F*, Liquid Haskell (high) vs. Coq (low)
- Learning curve: TLA+ (gentle) vs. Coq (steep)
- Industry support: SPARK Ada (avionics), HACL* (crypto)
- Performance needs: Vale (verified assembly), Low* (verified C)
```

---

## Verification Spectrum

| Approach | Automation | Soundness | Precision | Scalability | Learning Curve |
|----------|-----------|-----------|-----------|-------------|----------------|
| Testing | High | Unsound | False neg | Excellent | Low |
| Fuzzing | High | Unsound | False neg | Excellent | Low |
| Static Analysis | High | Sound | False pos | Good | Low-Medium |
| Model Checking | Medium | Sound | Complete | Limited | Medium |
| Symbolic Execution | Medium | Sound | Complete | Limited | Medium |
| SMT-based | High | Sound | Complete | Good | Medium |
| Refinement Types | High | Sound | Complete | Good | Medium-High |
| Dependent Types | Low | Sound | Complete | Medium | High |
| Interactive Proof | Low | Sound | Complete | Poor | Very High |

**Soundness**: Sound methods have no false negatives (if tool says "safe", it is safe).
**Precision**: Complete methods have no false positives (if tool says "unsafe", it is actually unsafe).

---

## Open Research Problems

### Problem 1: Proof Repair Automation

**Challenge**: When specifications change, proofs break. Can we automatically repair proofs?

**Current Work**:
- **Ornaments** (Coq): Relate similar data structures, transfer proofs
- **Proof refactoring**: Tools to update proofs after changes
- **Mutation-based repair**: Try small edits to fix proofs

**Impact**: Would dramatically reduce proof maintenance burden.

---

### Problem 2: Verified Machine Learning

**Challenge**: Neural networks lack formal semantics. How to verify safety properties?

**Current Work**:
- **Reluplex, Marabou**: Verify small networks (property verification)
- **DeepPoly, CROWN**: Abstract interpretation for neural networks
- **Probabilistic verification**: Verify statistical properties

**Impact**: Safe deployment of ML in safety-critical systems (autonomous vehicles, medical diagnosis).

---

### Problem 3: Usability Gap

**Challenge**: Proof assistants require PhD-level expertise. Can we democratize verification?

**Current Work**:
- **Copilot for proofs**: AI suggests proof steps (Tactician, Proverbot9001)
- **Neural theorem proving**: GPT-f, Thor learn from proof corpora
- **Better UX**: VS Code extensions, better error messages

**Impact**: 10x more developers can use formal methods.

---

### Problem 4: Verified Floating-Point Arithmetic

**Challenge**: Floating-point is subtle (rounding, overflow, NaN). Verify numerical algorithms?

**Current Work**:
- **Gappa**: Automated proof of numerical properties
- **FPTaylor**: Taylor expansion for FP error bounds
- **Herbie**: Automatically improve FP expression accuracy

**Impact**: Verified scientific computing, simulation, numerical solvers.

---

### Problem 5: Continuous Verification

**Challenge**: CI/CD for proofs. Fast incremental proof checking when code changes.

**Current Work**:
- **Coq SerAPI**: Serializable protocol for incremental checking
- **LSP for proof assistants**: Language Server Protocol integration
- **Proof caching**: Reuse unchanged proof fragments

**Impact**: Integrate formal verification into standard dev workflows.

---

## Corollaries

**Metaprinciple: Proof effort proportional to criticality.**
Safety-critical systems justify formal verification cost. Cost-benefit analysis guides degree of formality.

**Partial Verification Valuable**: Verify critical properties (memory safety, key invariants) even if full functional correctness infeasible.

**Compositionality Essential**: Modular proofs scale. Monolithic proofs don't. Verified components compose.

**Specification Hardest Part**: Formalizing requirements exposes ambiguity, contradictions, omissions. Specification debugging precedes implementation. Budget time accordingly.

**Interactive Theorem Proving**: Current automation insufficient for complex proofs. Human guidance necessary. Tools improve incrementally but won't achieve full automation soon.

**Verified Extractors**: From proof assistant to efficient code (CompCert, CakeML). Extraction soundness critical.

**Proof Maintenance is Real**: Budget 20-40% of verification effort for proof maintenance as code evolves.

**Start Incrementally**: Don't attempt full formal verification on first try. Use [Incremental Formalization](#xvi-incremental-formalization) pathway.

---

## Proof Assistant Ecosystem

### General Purpose

- **Coq**: Mature, large ecosystem (mathcomp, Iris), extraction to OCaml/Haskell
- **Isabelle/HOL**: Powerful automation (sledgehammer), strong in mathematics
- **Lean**: Modern, extensive mathlib, category theory, good UX
- **Agda**: Dependently typed, Unicode, cubical type theory

### Systems Verification

- **F***: Refinement types, SMT integration, cryptography (HACL*)
- **Dafny**: Automatic verification, imperative style, C#-like syntax
- **SPARK Ada**: Contracts, industrial use (avionics, rail), mature tooling
- **Why3**: Backend-agnostic, multiple provers (Alt-Ergo, Z3, CVC4)

### Concurrency

- **Iris**: Higher-order concurrent separation logic in Coq
- **Viper**: Permission-based verification, Silver language
- **TLA+**: Temporal logic, model checking, distributed systems

### Low-Level

- **Vale**: Verified assembly, integration with F*
- **Jasmin**: Verified high-assurance cryptography
- **Cogent**: Verified file systems, Linux drivers

---

## Industrial Applications

**Operating Systems**: seL4 (microkernel), CertiKOS
**Compilers**: CompCert (C), CakeML (ML)
**Cryptography**: HACL* (TLS 1.3, Signal), miTLS, Everest (HTTPS stack)
**File Systems**: FSCQ, Cogent (Linux ext2)
**Processors**: Hardware verification (Intel, AMD using formal methods post-Pentium FDIV bug)
**Aerospace**: SPARK Ada avionics (Airbus A380, Boeing 787), DO-178C Level A
**Automotive**: MISRA C + static analysis, ISO 26262
**Finance**: Smart contract verification (Ethereum, Cardano, Tezos)
**Distributed Systems**: TLA+ at AWS (S3, DynamoDB, EC2), Azure Cosmos DB
**Medical Devices**: FDA guidance on formal methods for safety-critical software

---

## Cost-Benefit Analysis

### High Verification ROI

- **Safety-critical**: Avionics, medical devices, automotive (bug cost ≫ proof cost)
- **Security-critical**: Cryptography, authentication, privilege escalation
- **Bug cost > proof cost**: Space missions (Mars rovers), financial infrastructure
- **Reusable libraries**: Standard library, crypto primitives, numerical algorithms
- **Regulatory requirements**: DO-178C, Common Criteria, FDA Class III

**Example**: seL4 verification cost ~20 person-years. Resulted in zero bugs in 9,000 lines of kernel code. Traditional OS kernels have 1-5 bugs per 1000 lines.

### Low Verification ROI

- **Prototype/MVP**: Requirements unstable, specification churn
- **UI/presentation layer**: Correctness intuitive, bugs non-critical
- **Frequently changing**: Code churn exceeds proof value
- **Non-critical utilities**: Bug impact minimal, users can work around
- **Lack of expertise**: Team learning curve too steep for project timeline

### Calculating ROI

**Formula**:
```
ROI = (Cost of Bugs Prevented - Cost of Verification) / Cost of Verification

Where:
Cost of Bugs = (Probability of Critical Bug) × (Cost of Critical Bug)
Cost of Verification = (Person-Hours) × (Hourly Rate) + (Tool Licenses)
```

**Example** (avionics):
- Probability of critical bug: 5% (1 in 20 components)
- Cost of critical bug: $50M (aircraft recall + lawsuits)
- Expected cost of bugs: 0.05 × $50M = $2.5M
- Verification cost: 5 person-years × $150K/year = $750K
- ROI = ($2.5M - $750K) / $750K = **233% return**

---

## Metrics for Verification Success

### Code Coverage Metrics

- **Verified LOC**: Lines of code with formal proofs
- **Specification coverage**: % of API surface with formal specs
- **TCB size**: Trusted Computing Base lines (smaller = better)
- **Proof-to-code ratio**: Typical ratios:
  - Coq: 3-10 lines of proof per line of code
  - Dafny: 0.5-2 lines (higher automation)
  - F*: 1-3 lines (SMT automation)

### Quality Metrics

- **Bugs found by verification vs. testing**: Track how many bugs each method finds
- **Post-deployment bugs**: Verified vs. unverified components
- **Security vulnerabilities**: CVEs in verified vs. unverified code
- **Time to find bugs**: Verification catches bugs earlier (cheaper to fix)

### Organizational Metrics

- **Developer training time**: Weeks to productivity with verification tools
- **Proof maintenance burden**: % of development time spent maintaining proofs
- **Developer satisfaction**: Survey developers on verification experience
- **Verification velocity**: Verified LOC per person-month (tracks team improvement)

---

## References and Further Reading

### Textbooks

- **Software Foundations** (Pierce et al.): https://softwarefoundations.cis.upenn.edu/
- **Certified Programming with Dependent Types** (Chlipala): http://adam.chlipala.net/cpdt/
- **Types and Programming Languages** (Pierce)
- **Concrete Semantics** (Nipkow, Klein): Isabelle/HOL

### Papers

- **seL4**: "seL4: Formal Verification of an OS Kernel" (Klein et al., SOSP 2009)
- **CompCert**: "Formal Verification of a Realistic Compiler" (Leroy, CACM 2009)
- **HACL***: "HACL*: A Verified Modern Cryptographic Library" (Zinzindohoué et al., CCS 2017)
- **Iris**: "Iris: Monoids and Invariants as an Orthogonal Basis for Concurrent Reasoning" (Jung et al., POPL 2015)

### Online Resources

- **TLA+ Hyperbook**: https://learntla.com/
- **Dafny Tutorial**: https://dafny.org/
- **Iris Tutorial**: https://iris-project.org/tutorial-material.html
- **SPARK Ada**: https://www.adacore.com/about-spark

### Industrial Case Studies

- **AWS and TLA+**: https://lamport.azurewebsites.net/tla/amazon.html
- **seL4 Whitepaper**: https://sel4.systems/About/seL4-whitepaper.pdf
- **CompCert Users**: http://compcert.inria.fr/users.html

---

**Version**: 1.1
**Last Updated**: 2024
**Changelog**:
- Added Principle XVI: Incremental Formalization
- Added Decision Tree for tool selection
- Added Common Pitfalls section
- Added Learning Paths for practitioners, researchers, managers
- Added Open Research Problems
- Expanded specification validation (Principle I)
- Added "Explained" subsections for complex principles (II, V, XIV)
- Expanded distributed systems coverage (Principle XIV)
- Corrected overclaims (Principles VI, XIII, XV)
- Added metrics for verification success
- Improved cost-benefit analysis with concrete ROI formula

**Contributors**: Community contributions welcome. Submit issues/PRs to improve this manifesto.

**License**: CC0 - Public Domain. Use freely for education, research, and industry.
