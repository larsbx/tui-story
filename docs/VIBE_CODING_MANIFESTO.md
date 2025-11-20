# Vibe Coding Manifesto: 15 Foundational Principles

**Version**: 2.0
**Classification**: Public
**License**: CC0 - Public Domain

---

## Scope & Applicability

**These principles apply to human-maintained production code** in long-lived systems where readability, maintainability, and correctness are primary concerns.

**These principles may not apply to**:
- Rapid prototypes and experimental code
- Performance-critical systems (without profiling justification)
- Machine-generated code
- One-off scripts and glue code
- Legacy codebases (without incremental migration strategy)

**Metaprinciple**: *Code optimizes for human cognition, not machine execution.*
Compilers optimize machine code. Humans optimize human code. Readability paramount.

---

## Core Principles (Universal — Start Here)

These principles transcend language and paradigm. Every team should adopt these regardless of context.

### I. Aesthetic Legibility
**Code shall read as prose; visual structure mirrors logical structure; beauty aids comprehension.**

Code is read 10× more than written. Formatting, naming, and organization create immediate cognitive grasp. Visual harmony reduces mental friction. Elegant code feels correct before analysis proves it.

**Concrete guidelines**:
- Max line length: 80-100 characters
- Max nesting depth: 3 levels
- Max function length: 25 lines (guideline, not law)
- Vertical alignment: related elements column-aligned for pattern recognition
- Symmetry: parallel constructs formatted identically
- Whitespace: logical grouping through spacing, not comments
- Typographic rhythm: consistent indentation, visual weight

```python
# Anti-pattern: cramped, irregular
def calc(x,y,z):
  if x>0:return x*y+z
  elif x<0:return abs(x)*y-z
  else:return z

# Vibe: spacious, symmetric, rhythmic
def calculate(x, y, z):
    if x > 0:  return  x * y + z
    if x < 0:  return |x| * y - z
    return z
```

**When to violate**:
- Generated code (machine output)
- Extreme embedded constraints (code golf for size)
- Team uses auto-formatter with different conventions (consistency > ideal)

**Tooling**: Prettier (JS/TS), Black (Python), rustfmt (Rust), gofmt (Go)

---

### IV. Intentional Naming
**Names reveal purpose unambiguously; pronunciation natural; length proportional to scope.**

Variable names encode type, purpose, lifecycle. Avoid generic terms. Pronounceable ≠ verbose. Short names in tight scopes; descriptive names in broad scopes.

- Loop iterators: `i`, `j`, `k` for indices; `user`, `item` for domain objects
- Booleans: `isActive`, `hasPermission`, `canEdit` (predicate form)
- Functions: verbs for actions, nouns for queries: `sendEmail()`, `userName()`
- Avoid: `data`, `info`, `manager`, `handler`, `obj`, `temp`, `foo`, `utils`

```rust
// Anti-pattern: vague, stuttering
fn process_data(data: Data) -> ProcessedData { }
let user_data_manager = UserDataManager::new();

// Vibe: precise, euphonic
fn normalize(raw: Measurements) -> Statistics { }
let users = UserRepository::new();
```

**Scope-to-length ratio**:
- 1-5 lines: single letter acceptable (`x`, `i`, `acc`)
- 5-20 lines: abbreviated acceptable (`usr`, `idx`, `cfg`)
- 20-100 lines: descriptive required (`currentUser`, `configIndex`)
- 100+ lines or public API: maximally clear (`authenticatedUserAccount`)

**When to violate**:
- Mathematical code where single letters match equations (physics simulation)
- Established idioms (`i` for index, `k` for key, `v` for value)
- Callback parameters when type is obvious: `users.map(u => u.id)`

---

### VIII. Literate Programming
**Code explains itself; comments explain why, not what; documentation lives adjacent to implementation.**

Self-documenting code: clear names, obvious structure. Comments for rationale, not narration. Docstrings for API contracts. Examples inline.

```python
# Anti-pattern: redundant comments
# increment counter by 1
counter = counter + 1

# Anti-pattern: absent context
# apply correction factor
value *= 1.049

# Vibe: rationale provided
# NIST correction factor for altitude-adjusted barometric pressure
value *= NIST_ALTITUDE_CORRECTION
```

**Comment types**:
- Rationale: why this approach chosen, alternatives considered
- Gotchas: `// WARNING: must be called before init(); race condition otherwise`
- TODOs: `// TODO(@username): migrate to v2 API by 2025-Q2`
- Temporal context: `// Workaround for Bug #1234; remove when fixed upstream`
- Domain knowledge: `// CAP theorem: prioritizing availability over consistency here`

**When to violate**:
- Regulatory/compliance code requiring extensive documentation
- Algorithms implementing papers (cite equations, authors)
- Public APIs (exhaustive docstrings mandatory)

---

### XIII. Obviousness Over Cleverness
**Prefer obvious over clever; boring over novel; straightforward over sophisticated.**

Clever code is write-once-read-never. Boring code is maintainable. Obvious solutions scale across team skill levels. Cleverness requires justification.

```python
# Anti-pattern: clever one-liner
result = reduce(lambda a,b: a+[b] if b not in a else a, lst, [])

# Vibe: obvious intent
result = list(dict.fromkeys(lst))  # preserve order, remove duplicates

# Or even better: explicit algorithm
result = []
seen = set()
for item in lst:
    if item not in seen:
        result.append(item)
        seen.add(item)
```

**Heuristics**:
- If you're proud of code's cleverness, rewrite it
- Fancy language features must earn their complexity budget
- Premature optimization forbidden; measured optimization encouraged
- Code golf is sport, not engineering
- Nested comprehensions beyond 2 levels: refactor

**When cleverness is justified**:
- Performance-critical path after profiling
- Leveraging language idioms team universally understands
- Established design patterns (even if initially non-obvious)

**Resolution of Principle II vs. XIII conflict**: When density conflicts with obviousness, **obviousness wins** unless:
1. Team has demonstrated fluency in the idiom (code review confirms)
2. Performance profiling justifies the abstraction
3. Pattern is well-documented and reusable

---

### XII. Locality & Cohesion
**Related code lives together; unrelated code stays apart; dependency direction deliberate.**

High cohesion within modules; low coupling between modules. Functional cohesion > sequential > communicational. Feature folders > layer folders.

```
// Anti-pattern: technical layers
src/
  controllers/
    user.controller.ts
  services/
    user.service.ts
  repositories/
    user.repository.ts
  models/
    user.model.ts

// Vibe: feature cohesion
src/
  users/
    domain.ts     // types, pure logic
    api.ts        // HTTP interface
    storage.ts    // persistence
    index.ts      // public exports
  orders/
    domain.ts
    api.ts
    storage.ts
    index.ts
```

**Dependency rules**:
- Acyclic dependencies: DAG, never cycles
- Dependency inversion: domain independent of infrastructure
- Dependencies flow inward: API → domain ← storage
- Screaming architecture: folder structure reveals business domain

**When to violate**:
- Small projects (<5k LOC): single folder acceptable
- Framework conventions (Rails, Django force layer separation)
- Shared infrastructure truly used everywhere (logging, config)

**Measuring cohesion**: Files in same folder should change together. If `users/api.ts` changes never require `users/storage.ts` changes, reconsider grouping.

---

## Intermediate Principles (Language-Dependent — Adopt Selectively)

These principles provide significant value but require language support or team skill development.

### II. Semantic Density ⚖️ Balanced with Obviousness
**Express concepts at appropriate abstraction level; verbosity is noise; terseness without obscurity.**

Express concepts at the appropriate abstraction level for your **team's shared fluency**. Dense ≠ cryptic; every character justified. Code golf discouraged; semantic compression encouraged.

**Critical qualifier**: Density is only valuable when the team shares fluency in the idiom. When in doubt, favor explicitness (Principle XIII).

```python
# Context: Python team familiar with functional patterns
users.filter(active).map(email)  # ✓ if team knows filter/map

# Context: Python team from imperative background
active_users = [u for u in users if u.is_active]  # ✓ more idiomatic
emails = [u.email for u in active_users]

# Anti-pattern: Cleverness disguised as density
emails = [u.email for u in users if (lambda x: x.is_active)(u)]
```

**Guidelines**:
- Short-circuit evaluation: `if !valid: return` > `if not valid: return None  # early exit`
- Pipeline composition where idiomatic: `data |> parse |> validate |> transform`
- Method chaining: `query.filter(active).order_by(name).limit(10)`
- List comprehensions in Python, LINQ in C#, streams in Java

**Language-specific density thresholds**:

| Language | Dense is OK | Too Dense |
|----------|-------------|-----------|
| Haskell | `sum . map price` | `(>>=) . (<=<)` without context |
| Python | `[x*2 for x in xs if x>0]` | `reduce(lambda...)` chains |
| JavaScript | `users.filter(u => u.active)` | `.reduce()` with complex accumulator |
| Rust | `iter().filter().map().collect()` | Type-level programming tricks |

**When to violate**:
- Debugging sessions (verbosity aids comprehension)
- Onboarding new team members (explicit until fluent)
- Performance logging (explicit values over computed)

**Resolution with Principle XIII**:
- If a code reviewer flags it as "clever", it's too dense
- If team can't explain it in < 10 seconds, it's too dense
- If you need a comment to explain the compression, it's too dense

---

### IX. Immutability Default
**Data transformed, not mutated; pure functions preferred; side effects explicit and isolated.**

Immutable by default; mutable when justified by measurement. Transformations create new values. Referential transparency enables reasoning. State mutations quarantined.

```javascript
// Anti-pattern: mutation, implicit effects
function addItem(cart, item) {
  cart.items.push(item);
  cart.total += item.price;
  saveCart(cart);  // hidden side effect
  return cart;
}

// Vibe: pure transformation, explicit effects
const addItem = (cart, item) => ({
  ...cart,
  items: [...cart.items, item],
  total: cart.total + item.price
})

const addItemWithPersistence = (cart, item) => {
  const updated = addItem(cart, item)
  saveCart(updated)  // explicit side effect
  return updated
}
```

**Guidelines**:
- `const` by default, `let` when necessary, `var` never (JavaScript/TypeScript)
- Avoid: in-place sort, splice, property assignment
- Functional core, imperative shell architecture
- Persistent data structures for efficient immutability

**Language support**:

| Language | Native Support | Library Needed |
|----------|----------------|----------------|
| Haskell/Elm | ✓✓✓ Immutable by default | - |
| Rust | ✓✓ `let` immutable by default | - |
| JavaScript | ~ Spread operators, Object.freeze | Immutable.js, Immer |
| Python | ~ Tuples, frozen dataclasses | pyrsistent |
| Java | ~ `final` keyword | Vavr, Immutables |

**When to violate (with profiling)**:
- High-frequency updates (game loops, real-time systems)
- Large collections (>10k elements) with frequent modifications
- Memory-constrained environments (embedded, mobile)
- Performance-critical hot paths (after measurement shows impact)

**Migration strategy**: Start with immutability; profile; add strategic mutation only where measured necessary.

---

### XIV. Contextual Verbosity
**Verbosity inversely proportional to scope and frequency; compress hot paths; elaborate boundaries.**

Tight loops: terse. Public APIs: explicit. Domain core: ubiquitous language. Infrastructure: standard patterns.

```scala
// Tight scope: terse
for (x <- xs if x > 0) yield x * 2

// Module boundary: explicit
def transformPositiveElements(
  elements: Seq[Int],
  transformation: Int => Int
): Seq[Int] = {
  elements
    .filter(_ > 0)
    .map(transformation)
}

// Public API: maximally clear
/**
 * Applies transformation function to positive integers in collection.
 *
 * @param elements Collection of integers to process
 * @param transformation Function applied to each positive element
 * @return New collection containing transformed positive elements
 * @throws IllegalArgumentException if transformation is null
 */
def transformPositiveElements(
  elements: java.util.List[Integer],
  transformation: java.util.function.Function[Integer, Integer]
): java.util.List[Integer]
```

**Verbosity guidelines by visibility**:

| Scope | Naming | Documentation | Type Annotations |
|-------|--------|---------------|------------------|
| Private helper (5 lines) | `x`, `acc` | None | Optional |
| Private function (50 lines) | `currentUser` | Inline comment | Recommended |
| Internal module API | `authenticatedUser` | Docstring | Required |
| Public library API | `getAuthenticatedUserAccount` | Full docstring + examples | Required + contracts |

**When to violate**:
- Domain-specific ubiquitous language may be terse but precise
- Team convention differs (consistency > ideal)

---

### XV. Joyful Craft
**Code as artistic medium; programming as creative expression; beauty as feature, not luxury.**

Code endures. Make it worth reading. Take pride in craftsmanship. Aesthetics and correctness align. Ugly code usually wrong; beautiful code often right.

- Refactor for elegance, not just correctness
- Delete code aggressively; less is more
- Symmetry, rhythm, proportion in code structure
- Programming as dialogue with future self and colleagues
- Code reviews appreciate aesthetic alongside functional qualities

**Measuring joy** (subjective but useful):
- Would you demo this code to peers with pride?
- Does reading this code teach something valuable?
- Does the structure reveal the problem's inherent elegance?
- Would you enjoy maintaining this in 2 years?

**When to deprioritize**:
- Hard deadlines requiring pragmatic shortcuts (document technical debt)
- Exploratory prototypes (joy comes from discovery, not code quality)
- Vendor integrations (external API ugliness unavoidable)

---

## Advanced Principles (Requires Strong Type Systems or FP Experience)

These principles deliver transformative benefits but require significant language support and team expertise.

### V. Type as Documentation
**Type signatures express invariants; impossible states unrepresentable; compiler as proof assistant.**

Leverage type system for correctness. Make illegal states unrepresentable. Rich types over primitive obsession. Parse, don't validate.

```typescript
// Anti-pattern: stringly typed, runtime checks required
function getUser(id: string): User | null { }
if (user && user.age >= 18) { }

// Vibe: types encode constraints
type UserId = Brand<string, 'UserId'>
type Adult = User & { age: Min<18> }
function getUser(id: UserId): Option<User>
function requireAdult(user: User): Result<Adult, AgeError>
```

**Type system ladder** (adopt progressively):

1. **Basic**: Primitives vs. domain types (`string` → `EmailAddress`)
2. **Intermediate**: Newtype pattern (`UserId` ≠ `ProductId`)
3. **Advanced**: Sum types (`Result<T, E>`, `Option<T>`)
4. **Expert**: Phantom types, GADTs, dependent types

**Language capability matrix**:

| Language | Newtype | Sum Types | Phantom | Dependent | Notes |
|----------|---------|-----------|---------|-----------|-------|
| Haskell | ✓✓✓ | ✓✓✓ | ✓✓✓ | ✓✓ | Industry leader |
| Rust | ✓✓✓ | ✓✓✓ | ✓✓ | ~ | Excellent ergonomics |
| TypeScript | ✓✓ | ✓✓ | ✓ | ~ | Structural typing quirks |
| Python | ✓ | ~ | ~ | ✗ | Runtime validation needed |
| Go | ~ | ~ | ✗ | ✗ | Deliberately minimal |
| Java | ✓ | ~ | ~ | ✗ | Verbose boilerplate |

**Fallback strategies for weak type systems**:

```python
# Python: Use dataclasses with validation
from dataclasses import dataclass
from typing import NewType

UserId = NewType('UserId', str)

@dataclass(frozen=True)
class Adult:
    user: User

    def __post_init__(self):
        if self.user.age < 18:
            raise ValueError("User must be 18 or older")
```

**When to violate**:
- Rapid prototyping (add types after stabilization)
- Scripting languages where types unavailable
- Performance overhead measured as unacceptable

**Adoption path**: Start with newtypes, add sum types, defer advanced features until team fluency builds.

---

### VI. Composition Over Configuration
**Small functions compose into large systems; orthogonal concerns separated; Unix philosophy applied.**

Functions do one thing, take one argument, return one value. Compose via pipes, chains, higher-order functions. Configuration is code in disguise.

```javascript
// Anti-pattern: monolithic, configurable
function processUser(user, options = {
  validate: true,
  transform: true,
  persist: true,
  notify: true
}) {
  if (options.validate) { /* validate */ }
  if (options.transform) { /* transform */ }
  // ...
}

// Vibe: composable pipeline
const processUser = flow(
  validate,
  transform,
  persist,
  notify
)

// Or with selective composition
const processUserQuickly = flow(validate, persist)
const processUserFully = flow(validate, transform, persist, notify)
```

**Composition patterns**:
- Point-free style: `map(f)` > `xs => xs.map(f)`
- Function composition: `(f ∘ g)(x) = f(g(x))`
- Currying for partial application: `map(add(2))` instead of `map(x => add(x, 2))`
- Monadic bind for sequencing effects

**Language support**:

| Language | Native Composition | Library | Notes |
|----------|-------------------|---------|-------|
| Haskell | ✓✓✓ `.` operator | - | Language built for this |
| Rust | ✓✓ Iterators | - | Excellent ergonomics |
| JavaScript | ~ | Ramda, lodash/fp | Not idiomatic |
| Python | ~ | toolz, funcy | Not idiomatic |
| Java | ~ | Vavr | Verbose |

**When to violate**:
- Language lacks composition support (Go, traditional Java)
- Team unfamiliar with FP (high onboarding cost)
- Imperative style more readable for specific algorithm

**Adoption path**: Start with simple chaining (`.map().filter()`), progress to pipelines, defer point-free style.

---

### X. Error as Value
**Errors are data, not control flow; failure modes explicit in return types; exceptions for exceptional circumstances only.**

Return `Result<T, E>` or `Option<T>`. Pattern match on outcomes. Railway-oriented programming. Exceptions for programmer errors (assertions) only.

```rust
// Anti-pattern: exceptions for control flow
fn divide(a: f64, b: f64) -> f64 {
    if b == 0.0 { panic!("division by zero") }
    a / b
}

// Vibe: error as value
fn divide(a: f64, b: f64) -> Result<f64, DivisionError> {
    if b == 0.0 { Err(DivisionError::ZeroDivisor) }
    else { Ok(a / b) }
}

// Railway-oriented programming
user_id
    .and_then(fetch_user)
    .and_then(validate_permissions)
    .map(perform_action)
```

**Exception guidelines**:
- **Use exceptions for**: Programming errors (null pointer, array bounds, assertion failures)
- **Use Result/Option for**: Expected failure modes (not found, validation, network errors)

**Language support**:

| Language | Native Support | Library | Ergonomics |
|----------|----------------|---------|------------|
| Rust | ✓✓✓ `Result<T,E>`, `?` operator | - | Excellent |
| Haskell | ✓✓✓ `Either`, `Maybe` | - | Excellent |
| Swift | ✓✓ `throws`, `Result` | - | Good |
| Go | ✓ Multiple returns | - | Verbose but explicit |
| TypeScript | ~ | fp-ts, neverthrow | Not idiomatic |
| Python | ~ | returns, result | Not idiomatic |
| Java | ~ | Vavr, Try | Verbose |

**Fallback for languages without Result types**:

```python
# Python: Use exception types judiciously
class ValidationError(Exception):
    """Expected failure mode"""
    pass

def validate_user(user: User) -> User:
    if not user.email:
        raise ValidationError("Email required")
    return user

# Or use explicit tuples
def divide(a: float, b: float) -> tuple[float | None, str | None]:
    if b == 0:
        return (None, "Division by zero")
    return (a / b, None)
```

**When to violate**:
- Language/framework enforces exceptions (Java checked exceptions)
- Interfacing with exception-based libraries
- Performance critical (Result has overhead in some languages)

---

### XI. Constraint Propagation
**Compile-time > runtime > testing > documentation > convention.**

Push guarantees leftward on timeline. Encode invariants in types. Leverage compiler for proof. Tests for properties, not examples.

```typescript
// Hierarchy of guarantees (best to worst)

// 1. Type system (compile-time) — BEST
type NonEmptyArray<T> = [T, ...T[]]
function head<T>(arr: NonEmptyArray<T>): T { return arr[0] }

// 2. Runtime assertions (fail fast) — GOOD
function head<T>(arr: T[]): T {
  assert(arr.length > 0, "array must not be empty")
  return arr[0]
}

// 3. Property-based tests — ACCEPTABLE
property("head(cons(x, xs)) == x", forAll(...)

// 4. Unit tests — MINIMAL
test("head([1,2,3]) === 1")

// 5. Documentation — WEAK
// @param array - must be non-empty
function head<T>(arr: T[]): T { return arr[0] }

// 6. Convention (hope) — WORST
function head<T>(arr: T[]): T { return arr[0] }
```

**Progressive constraint encoding**:

| Constraint | Type System | Runtime | Test | Doc |
|------------|-------------|---------|------|-----|
| Non-empty array | `[T, ...T[]]` | `assert(len > 0)` | Property test | Comment |
| Positive number | `Positive<number>` | `assert(n > 0)` | Property test | Comment |
| Valid email | `Email` newtype | Validation fn | Example test | Format spec |
| Sorted array | `Sorted<T[]>` phantom | Check on creation | Property test | Comment |

**When to violate**:
- Type system incapable (weak typing)
- Performance overhead measured (rare)
- External data sources (parse at boundary)

---

### VII. Visual Symbolism ⚠️ Use Judiciously
**Operators convey meaning through shape; ASCII art for complex structures; Unicode only where ergonomic.**

**WARNING**: This principle has significant trade-offs. Only adopt where tooling fully supports Unicode input/display.

```haskell
-- Mathematical operators (where supported)
(+), (*), (^), (/)          -- arithmetic
(<), (>), (≤), (≥)          -- comparison (if tooling supports)
(&&), (||), (!)             -- logical (ASCII fallback: ∧, ∨, ¬)

-- Functional combinators (ASCII recommended)
(|>)  -- forward pipe:    x |> f |> g
(>>)  -- composition:      f >> g
(<$>) -- fmap:             f <$> maybe
(>>=) -- bind:             m >>= f
```

**ASCII art for documentation**:

```
// State machine visualization
// [Idle] --start--> [Running] --pause--> [Paused]
//   ^                  |                   |
//   |                stop                resume
//   +------------------+-------------------+

// Tree structure
//     root
//    /    \
//  left  right
//         /  \
//      childA childB
```

**Emoji as semantic markers** (optional, team preference):
- `// 🔥 Performance hot path`
- `// 🐛 Known issue: Bug #1234`
- `// 🎯 TODO: Refactor after v2`
- `// ⚠️ WARNING: Thread-unsafe`

**Critical constraints**:
- ✗ Do not use if team uses SSH/terminal-only environments
- ✗ Do not use if grep/search becomes difficult
- ✗ Do not use if keyboard input is cumbersome
- ✓ OK for LaTeX-adjacent domains (academic, math-heavy)
- ✓ OK if IDE has excellent Unicode input support (Emacs, Vim with plugins)

**Accessibility concerns**:
- Screen readers may not pronounce Unicode operators correctly
- Developers with visual impairments may have difficulty distinguishing symbols
- Non-native English speakers may find ASCII more universal

**Recommendation**: **Default to ASCII**. Use Unicode only in specialized contexts (mathematical libraries, academic research code) where team has explicit buy-in and tooling support.

---

## Supporting Principles

### III. Flow State Optimization
**Code structure minimizes context switching; deep work facilitated; cognitive load managed.**

Locality of reference: related code proximate. Minimal jumping between files. Dependencies flow downward. State mutations explicit and bounded.

- Related functions clustered by usage, not alphabetized
- Dependencies imported once at top, grouped semantically
- Hot paths optimized for reading flow top-to-bottom
- Deeply nested code refactored; max nesting depth: 3
- Cyclomatic complexity: ≤ 10 per function

```typescript
// Anti-pattern: scattered, requires jumping
import { validateUser } from './validation/user'
// ... 200 lines ...
import { formatError } from './formatting/error'
// ... 100 lines ...
import { User } from './types/user'

// Vibe: grouped by semantic relationship
import { User, Result } from './types'
import { validateUser, validateEmail, validateAge } from './validation'
import { formatError, formatSuccess } from './formatting'
```

**File size guidelines**:
- Max 300 lines per file (guideline, not law)
- If >300 lines, consider splitting by cohesive responsibility
- Related files in same directory

**When to violate**:
- Code generators produce large files (acceptable if not hand-edited)
- Single-responsibility file happens to be long (state machine tables, etc.)

---

## New Sections

### XVI. Collaborative Aesthetics
**Team consensus > individual preference; automate style to minimize conflict; local variation within bounds.**

Aesthetic disagreements consume disproportionate energy. Establish team conventions early, automate enforcement, move on to meaningful work.

**Hierarchy of style authority**:
1. **Language idioms**: Follow community conventions (PEP 8 for Python, Rustfmt defaults)
2. **Auto-formatter**: Prettier, Black, rustfmt — non-negotiable consistency
3. **Team style guide**: Document decisions not covered by formatter
4. **Individual preference**: Acceptable within module scope only

**Documenting style decisions**:
- Use ADRs (Architecture Decision Records) for significant choices
- Example: "ADR-007: Why we use functional composition patterns"
- Capture rationale, alternatives considered, trade-offs

**Code review focus**:
- ✓ Logic, correctness, edge cases, security
- ✓ Architecture, design patterns, testability
- ~ Naming, structure (suggest, don't require)
- ✗ Formatting, whitespace (automated)

**When disagreements arise**:
1. Check if auto-formatter covers it → defer to tool
2. Check language conventions → follow community
3. Check existing codebase → consistency wins
4. Still disagree? → Document both options, choose one, move on
5. Time-box debate: 15 minutes maximum

**Personal style within constraints**:
- Public APIs: strict team standards
- Private helpers: individual variation acceptable
- Comments: personal voice encouraged (clarity required)

---

### Testing Philosophy

**Tests validate properties, not just examples; tests are documentation; test code deserves craft too.**

```python
# Anti-pattern: brittle example tests
def test_add():
    assert add(2, 3) == 5
    assert add(10, 20) == 30

# Better: property-based tests
@given(integers(), integers())
def test_add_commutative(a, b):
    assert add(a, b) == add(b, a)

@given(integers(), integers(), integers())
def test_add_associative(a, b, c):
    assert add(add(a, b), c) == add(a, add(b, c))
```

**Test principles**:
- Property-based tests > example tests
- Integration tests for workflows, unit tests for logic
- Test names describe behavior: `test_rejects_invalid_email`
- Arrange-Act-Assert pattern
- Tests should read like specifications

**Test code quality**:
- Tests follow same principles as production code
- Avoid test code duplication: use fixtures, factories
- Clear test names > comments
- One assertion per test (guideline, not law)

**Coverage guidelines**:
- Public APIs: 100% coverage required
- Business logic: >90% coverage
- Presentation layer: >70% coverage
- Glue code: smoke tests sufficient

**When to violate**:
- Prototype code (add tests before production)
- Generated code (test generator, not output)
- Truly trivial getters/setters

**Testing tools by language**:

| Language | Unit Testing | Property-Based | Coverage |
|----------|--------------|----------------|----------|
| Python | pytest | Hypothesis | coverage.py |
| JavaScript | Jest, Vitest | fast-check | Istanbul |
| Rust | built-in | proptest, quickcheck | tarpaulin |
| Haskell | HUnit | QuickCheck | HPC |
| Java | JUnit | jqwik | JaCoCo |

---

### Performance Philosophy

**Optimize for readability first; measure before optimizing; document performance trade-offs.**

Premature optimization is the root of all evil. Measure, then optimize. Document trade-offs.

**Optimization hierarchy**:
1. **Algorithm choice**: O(n²) → O(n log n) matters more than micro-optimizations
2. **Data structure selection**: HashMap vs. Array for use case
3. **Profiler-driven optimization**: Measure, identify hot spots, optimize
4. **Micro-optimizations**: Only in proven hot paths

**When principles conflict with performance**:

```rust
// Principle IX (Immutability) conflicts with performance
// Solution: Document the trade-off

// Immutable version (preferred for readability)
fn update_positions(entities: Vec<Entity>) -> Vec<Entity> {
    entities.into_iter()
        .map(|e| e.with_position(calculate_position(e)))
        .collect()
}

// Mutable version (profiled as 10x faster in game loop)
// PERF: Hot path in 60fps game loop; profiled 2024-01-15
fn update_positions_mut(entities: &mut [Entity]) {
    for entity in entities.iter_mut() {
        entity.position = calculate_position(*entity);
    }
}
```

**Performance documentation**:
- Add `// PERF:` comments with profiling results and date
- Document why optimization necessary
- Link to profiling data or benchmarks
- Consider separate `fast_*` function, keep readable version

**Benchmarking**:
- Use language-specific tools: Criterion (Rust), pytest-benchmark (Python)
- Set performance budgets: "This function must complete in <10ms"
- CI/CD integration to prevent regressions

**When to violate principles for performance**:
- Measured impact >50% on critical path
- User-visible latency reduction (UI responsiveness)
- Resource constraints (embedded, mobile battery)
- Always document with profiling data

---

### Incremental Adoption Strategy

**You cannot rewrite a codebase overnight. Adopt principles progressively, focusing on high-impact areas first.**

**Phase 1 (Weeks 1-2): Low Friction, High Impact**
- **Principle I** (Aesthetic Legibility): Add auto-formatter (Prettier, Black, rustfmt)
- **Principle IV** (Intentional Naming): Rename in new code only
- **Principle VIII** (Literate Programming): Improve comments in modified files
- **Principle XIII** (Obviousness): Simplify during refactoring

**Cost**: Minimal (mostly tooling setup)
**Benefit**: Immediate readability improvement

**Phase 2 (Months 1-2): Structural Improvements**
- **Principle IX** (Immutability): New functions immutable by default
- **Principle XII** (Locality): Reorganize next feature into feature folders
- **Principle XIV** (Contextual Verbosity): Apply to new public APIs

**Cost**: Moderate (refactoring time)
**Benefit**: Better maintainability, fewer bugs

**Phase 3 (Months 3-6): Architectural Changes**
- **Principle V** (Type as Documentation): Add newtypes to new modules
- **Principle X** (Error as Value): Migrate to Result types incrementally
- **Principle VI** (Composition): Refactor toward composable functions

**Cost**: Significant (architectural shifts)
**Benefit**: Transformative correctness and maintainability

**Mixed style during transition**:
- Use module-level comments: `// Legacy code: Pre-dates manifesto`
- Create "vibe-compliant" folder for new code
- Refactor opportunistically: touch a file, improve it
- Don't rewrite working legacy code without business justification

**Measuring adoption**:
- Track linter compliance rate
- Code review checklist: which principles applied?
- Team retrospectives: which principles help most?

---

### Language-Specific Guidance

**How principles translate across languages:**

#### Python
**Strong principles**: I, IV, VIII, XIII (PEP 8 alignment)
**Moderate principles**: IX (via dataclasses), XII (modules)
**Weak principles**: V, VI, VII, X (weak type system)

**Idiomatic adaptations**:
- Use `dataclasses` with `frozen=True` for immutability
- Use `typing` module for gradual typing
- Use `pytest` for testing
- Comprehensions over `map`/`filter` (more Pythonic)

#### TypeScript
**Strong principles**: I, IV, V, VIII, XII, XIII, XIV
**Moderate principles**: VI (not idiomatic), IX (spread operators), X (via libraries)
**Weak principles**: VII (Unicode not supported), XI (structural typing limits)

**Idiomatic adaptations**:
- Use discriminated unions for sum types
- Use branded types for newtypes
- Use `fp-ts` for functional patterns (if team has FP experience)
- Use `zod` for runtime validation

#### Rust
**Strong principles**: I, III, V, VI, IX, X, XI, XIII
**Moderate principles**: II (balance with readability), VII (ASCII preferred)
**Weak principles**: None (language designed for these principles)

**Idiomatic adaptations**:
- Embrace `Result<T, E>` and `Option<T>`
- Use type-driven design heavily
- Leverage compiler for correctness
- Zero-cost abstractions enable both readability and performance

#### Go
**Strong principles**: I, IV, VIII, XIII (simplicity focus)
**Moderate principles**: XII (modules)
**Weak principles**: V, VI, VII, IX, X, XI (deliberately minimal language)

**Idiomatic adaptations**:
- Embrace explicit error handling: `if err != nil`
- Use interfaces for abstraction (limited generics)
- Prioritize Principle XIII above all else
- Structured concurrency (goroutines, channels)

---

## Anti-Patterns to Avoid

- **Primitive Obsession**: Strings/ints everywhere → use domain types
- **Boolean Blindness**: `(bool, bool)` meaningless → use sum types or structs
- **Stringly Typed**: Parsing at use site → parse at boundary once
- **God Functions**: 500-line functions → compose from smaller pieces
- **Mutation Soup**: Unclear data flow → explicit transformations
- **Error Swallowing**: Silent failures → propagate or handle deliberately
- **Magic Numbers**: Unexplained constants → named constants with rationale
- **Nested Ifs**: Arrow anti-pattern → guard clauses or pattern matching
- **Over-Engineering**: YAGNI violation → solve today's problem, not tomorrow's maybe-problem
- **Dogmatic Application**: Following principles blindly → pragmatism when justified

**Cost of anti-patterns**:
- Primitive obsession: Type errors, invalid states
- Boolean blindness: Cannot distinguish (true, false) from (false, true)
- God functions: Impossible to test, reason about, reuse
- Error swallowing: Silent data corruption, debugging nightmares

**Refactoring paths**: See each principle's "When to violate" section for guidance.

---

## Metrics & Measurement

**How to assess vibe compliance (objectively where possible):**

### Automated Metrics (via linters, analyzers)
- **Cyclomatic complexity**: ≤10 per function (Principle III)
- **Function length**: ≤25 lines (Principle I)
- **Nesting depth**: ≤3 levels (Principle III)
- **Line length**: 80-100 characters (Principle I)
- **Test coverage**: >90% for business logic (Testing Philosophy)
- **Type coverage**: >80% in typed languages (Principle V)

### Code Review Checklist
- [ ] Names are intentional and clear (Principle IV)
- [ ] Comments explain why, not what (Principle VIII)
- [ ] Obvious approach chosen over clever (Principle XIII)
- [ ] Related code is colocated (Principle XII)
- [ ] Errors handled explicitly (Principle X)
- [ ] Immutability preferred (Principle IX)
- [ ] Public APIs fully documented (Principle XIV)

### Team Health Indicators
- Time to onboard new developer (should decrease)
- Bugs per release (should decrease)
- Code review iteration count (should decrease)
- Developer satisfaction surveys (should increase)

### Qualitative Assessment
- Would you demo this code proudly? (Principle XV)
- Does this teach something valuable? (Principle XV)
- Can team explain code in <1 minute? (Principles II, XIII)

---

## When This Manifesto Applies (And When It Doesn't)

### ✓ Best Fit
- Long-lived systems (10+ year horizon)
- Teams valuing correctness and maintainability
- Domains with complex business logic
- Libraries and frameworks (public APIs)
- Safety-critical systems (medical, aerospace, financial)

### ~ Conditional Fit
- Medium-sized projects (2-5 year horizon) — adopt core principles only
- Growing teams (establish conventions before scale)
- Greenfield projects (easier than retrofitting legacy)

### ✗ Poor Fit
- Throwaway prototypes (<1 month lifespan)
- Scripts and automation (<200 LOC)
- Research code (exploration > polish)
- Performance-critical systems without profiling budget
- Teams with high turnover (unless onboarding resources available)

---

## FAQ

**Q: What if my language doesn't support these principles?**
A: Focus on language-appropriate principles. Python: I, IV, VIII, XIII. Go: I, IV, VIII, XIII. See Language-Specific Guidance.

**Q: How do I convince my team to adopt this?**
A: Start small (Phase 1), demonstrate value, expand incrementally. Show, don't tell. One beautiful module is worth a thousand manifestos.

**Q: What if principles conflict?**
A: Hierarchy: XIII (Obviousness) > I (Legibility) > others. When in doubt, choose readable over clever.

**Q: How do I handle legacy code?**
A: Don't rewrite. Refactor opportunistically. Add tests, then improve. See Incremental Adoption Strategy.

**Q: What about performance?**
A: Measure first. Optimize only proven hot paths. Document trade-offs. See Performance Philosophy.

**Q: Is this just functional programming dogma?**
A: No. Core principles (I, IV, VIII, XIII, XII, XV) are paradigm-agnostic. Advanced principles (V, VI, X, XI) draw from FP but adapt to OOP.

**Q: What if I disagree with a principle?**
A: Principles are guidelines, not laws. Adapt to your context. Document your reasoning. Consistency within a project matters more than perfect adherence.

---

## Contributing & Evolution

This is a living document. Contributions welcome via:

1. **GitHub Discussions**: Propose new principles, refinements
2. **Pull Requests**: Language-specific adaptations, examples
3. **Case Studies**: Share adoption stories, lessons learned

**Versioning**:
- Major (X.0): New principles, significant restructuring
- Minor (1.X): Refinements, new sections, expanded guidance
- Patch (1.0.X): Typos, clarifications, examples

**Changelog**: See CHANGELOG.md for version history.

---

**Inspiration**: The Zen of Python, SICP, Domain-Driven Design, Functional Programming principles, A Philosophy of Software Design (John Ousterhout)

**Authors**: Community-driven (see CONTRIBUTORS.md)

---

## Appendix: Quick Reference

### Core Principles (Start Here)
I. Aesthetic Legibility
IV. Intentional Naming
VIII. Literate Programming
XIII. Obviousness Over Cleverness
XII. Locality & Cohesion

### Intermediate Principles
II. Semantic Density ⚖️
IX. Immutability Default
XIV. Contextual Verbosity
XV. Joyful Craft

### Advanced Principles
V. Type as Documentation
VI. Composition Over Configuration
X. Error as Value
XI. Constraint Propagation
VII. Visual Symbolism ⚠️

### Supporting
III. Flow State Optimization
XVI. Collaborative Aesthetics

### New Sections
- Testing Philosophy
- Performance Philosophy
- Incremental Adoption Strategy
- Language-Specific Guidance
- Metrics & Measurement

---

**End of Manifesto v2.0**
