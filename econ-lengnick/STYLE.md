# STYLE.md

A coding style for games written in Zig, derived from two sources:

- **[TigerStyle](docs/style/tiger_style.md)** (TigerBeetle), referred to as **[TS]**.
- **[The Power of 10](docs/style/power_of_10.md)** (Holzmann, NASA/JPL, 2006), referred to as **[P10]**.

Rules that come from neither source, or that deliberately depart from them, are marked **[GAME]**.
Section 11 lists every departure from upstream and why. When this document and an upstream
source disagree, this document wins for this codebase, but the upstream reasoning is worth
reading before you override anything.

This guide is independent of any windowing, graphics, audio, or input library. Wherever it
says "platform layer", it means whatever library you use to talk to the OS and GPU.

## 1. Why have a style

Following TS, the design goals are **safety, performance, and developer experience, in that
order**. Style is not about taste. Each rule below should be judged by whether it makes the
code safer, faster, or easier to work on. Readability is a means to those ends.

For a game, add one practical corollary **[GAME]**: *iteration speed is part of developer
experience.* A rule that makes you slower at trying ideas, without buying safety or
performance in the code that matters, belongs in the relaxed zone (section 2), not the strict
one.

Rules are written as **MUST** (enforced in review or by tooling), **SHOULD** (follow unless
you can say why not, in a comment), and **MAY**.

### Always say why

TS insists that every decision come with its rationale, because a reason lets the next reader
judge the rule's importance and apply it to cases the rule never anticipated. This document
tries to do that. Your code should too: comments explain why the code is the way it is, and
a test explains its goal and method at the top.

## 2. Zones, dependencies, and the sim API

P10 and TS were written for code where failure is very costly. Most game code is not that.
Applying maximum strictness everywhere makes prototyping painful, while applying none makes
the simulation untestable. **[GAME]** So the codebase is split by directory into a strict zone
and a relaxed zone.

### 2.1 Directories

**Strict zone** (every rule in this document applies):
- `base/`: shared foundation that any code may use. Math, fixed-capacity containers,
  allocators, handles, the PRNG, and the project `assert`.
- `sim/`: the simulation. Game state, the tick function, entity logic, physics, AI, rules, and
  the decoders for saves, replays, level data, and network messages. Its public surface is
  `sim/api.zig` (section 2.3).

**Relaxed zone** (rules marked *Strict zone only* do not apply):
- `app/`: the program around the sim. `main()`, the platform layer (windows, input devices,
  audio devices, GPU submission), the frame loop, rendering, asset loading and hot reload,
  file and network I/O, and debug UI.
- `tools/`: editors, the fuzz driver, and other separate executables.
- `scratch/`: throwaway prototypes, clearly labeled as such.

**Gameplay belongs in `sim`.** The test: if it can change the outcome of a tick, it lives in
`sim`. `app` translates between the outside world and the sim, and decides how things look and
sound. It does not decide what happens.

If the game ever becomes client-server, `sim` and `base` do not change. `app` becomes the shared
relaxed layer (config, logging, the event loop, socket transport, the asset pipeline), and
`client/` and `server/` are added on top of it as separate executables. That is why the rest of
this document says "relaxed zone" wherever a rule should also cover directories that do not
exist yet.

### 2.2 Dependency rules

Imports only go toward the strict zone, never out of it. **[GAME]**

- `base` **MUST** import only `std`, `builtin`, and its own files.
- `sim` **MUST** import only `std`, `builtin`, `base`, and its own files.
- Relaxed-zone code may import `base` and `sim`. It reaches `sim` only through `sim/api.zig`.
- Nothing imports `tools` or `scratch`. If `client` and `server` ever exist, they import `app`,
  `sim`, and `base`, and never each other.

Write these as an **allow-list**: say what `base` and `sim` may import, not what they may not.
New relaxed directories are then covered automatically.

The consequence is that **anything `sim` imports follows strict-zone rules**, even a general
utility. A math library the sim uses must be deterministic and allocation-free, so it lives in
`base`. This is what lets the sim build headless, run deterministically, and be tested without
opening a window.

**SHOULD** enforce the rules with the build graph, not only by review. Declare `base`, `sim`,
and `app` as separate modules in `build.zig`, give `sim` only `base` as a dependency, and make
`sim/api.zig` the root of the `sim` module. The compiler then rejects a forbidden import, and
relaxed code can only reach declarations that `api.zig` makes `pub`. Zig does not let a module
import files outside its own directory, which is what makes this work. Confirm that behavior
for your Zig version, and keep a text search as a backstop (see `AGENTS.md`).

Rules below say **Strict zone only** where the relaxed zone is exempt. Everything else applies
everywhere.

### 2.3 The sim API

Data crosses the boundary in both directions, but imports go only one way. So **every type
that crosses the boundary is defined by `sim`**, or by `base` if it is general vocabulary like
vectors or handles. The app translates its world into the sim's types on the way in, and the
sim's types into its own on the way out. **[GAME]**

- **MUST** declare every boundary type and every public sim function in `sim/api.zig`, or
  re-export it from there. This keeps the boundary reviewable in one file.
- **MUST NOT** import any `sim` file other than `api.zig` from relaxed-zone code.

There are four kinds of traffic.

1. **Commands, from the app to the sim.** The sim defines what a player can *intend* (move,
   fire, interact), not keys or buttons. The app maps devices to commands each frame. Debug
   tools and cheats also issue commands, so that using them does not make a replay
   irreproducible. A replay is then the seed plus the commands per tick. The fuzzer generates
   commands, and a future network client sends them.
2. **Events, from the sim to the app.** Anything the presentation reacts to (a sound, a
   particle burst, an entity dying) is written by the sim into a fixed-capacity event buffer,
   which the app drains after each tick. The sim **MUST NOT** call back into the app. A callback
   needs a function pointer, which the strict zone avoids **[P10-9]**, and it would run
   relaxed-zone code in the middle of a tick.
3. **State reads, from the sim to the app.** The app reads sim state for rendering through a
   `*const` pointer, and **MUST NOT** write it. All changes go through commands. Reading state
   directly couples rendering to the state's layout. If that becomes a problem, or rendering
   moves to another thread or to network snapshots, have the sim publish a snapshot struct
   instead. Interpolating between ticks is the app's job.
4. **Data at load time, from the app to the sim.** Level layouts, tuning tables, and saves come
   from files, but the sim does no I/O. The app reads the bytes, and `sim/api.zig` provides
   decoders, such as `level_decode(bytes) !LevelDefinition`, that validate them and return
   errors for bad data. Untrusted input is therefore validated inside the strict zone, where
   the rules are enforced. Network messages follow the same split: transport in the relaxed
   zone, decoding in `sim`.

The sim refers to presentation by its own small enums or IDs (`EntityKind.goblin`,
`SoundKind.footstep`), never by GPU handles, audio buffers, or file paths. The app keeps the
tables that map those IDs to real resources.

See the appendix for a sketch of `sim/api.zig`.

## 3. Safety

> TS quotes Holzmann's seat-belt analogy: rules feel uncomfortable at first, then become
> second nature. Expect the same.

### 3.1 Control flow

- **MUST** keep control flow simple and explicit. **[P10-1, TS]**
- **MUST NOT** use recursion in the strict zone. P10 bans it because it guarantees an acyclic
  call graph, which makes boundedness provable by tools and by humans. Where you need a tree or
  graph walk, use an explicit stack with a fixed capacity and assert on overflow. **[P10-1, TS]**
  *Strict zone only.*
- **SHOULD** keep abstractions to a minimum and only where they make the best sense of the
  domain. TS points out that abstractions are never zero cost and every one risks leaking. **[TS]**
- **SHOULD** split compound conditions into simple nested `if`/`else` branches, and split long
  `else if` chains into `else { if ... }` trees, so each case is visibly handled. If an `if`
  has no `else`, ask whether the negative case needs handling or an assertion. **[TS]**
- **SHOULD** state conditions positively. Prefer `if (index < count)` with the invariant in
  the true branch over `if (index >= count)`. **[TS]**
- **SHOULD** "push `if`s up and `for`s down": keep branching in the calling function, and move
  non-branching work into helpers. **[TS]**
- Early returns on error are fine. P10 explicitly does not require a single return point.
  **[P10-1]**

### 3.2 Put a limit on everything

- **MUST** give every loop with a variable iteration count an explicit upper bound, and assert
  that the bound is not exceeded. **[P10-2, TS]**
- **MUST** give every queue, buffer, and pool a fixed capacity, named by a constant.
  **[P10-2, TS]**
- **MUST**, for loops that are meant to run forever (the main loop is the usual one),
  make that visible: the loop is the top-level driver and its exit condition is explicit.
  P10 says to prove the opposite property for such loops, that they cannot terminate by
  accident, and TS says to assert it. **[P10-2, TS]**

```zig
// Bounded traversal: the limit is a named constant, and exceeding it is a bug.
var steps: u32 = 0;
var node = head;
while (node) |n| : (node = n.next) {
    steps += 1;
    assert(steps <= nodes_max);
    visit(n);
}
```

Choose limits from the design (the most enemies a level can contain, the longest path you
will ever search), not from what happens to work today. Then budget memory from those limits.

### 3.3 Types and numbers

- **MUST** use explicitly-sized integer types (`u32`, `i16`) for everything stored or
  computed in the strict zone. **SHOULD NOT** use `usize` or `isize` except at the language
  boundary (indexing slices, `@sizeOf`), converting once, at the edge. **[TS]**
- **SHOULD** treat *index*, *count*, and *size* as three different things even though they are
  all integers. An index is 0-based, a count is 1-based, and a size is a count times a unit.
  Convert deliberately and name the variables accordingly. **[TS]**
- **SHOULD** show intent with division: use `@divExact`, `@divFloor`, or an explicit
  ceiling-division helper so the reader knows rounding was considered. **[TS]**
- **SHOULD** pass a value by `*const` if it is larger than 16 bytes and you do not mean to
  copy it. This catches accidental stack copies at the call site. **[TS]**
- **MUST** zero or fully initialize padding and buffers that get serialized or hashed. An
  under-filled buffer is the opposite of an overflow and can leak data or, in a game, break
  determinism through state hashing. TS calls this a buffer bleed. **[TS]**
- Zig's default integer overflow checking in safe build modes is a feature. **MUST NOT**
  paper over it with wrapping operators (`+%`) unless wrapping is the intended semantics, in
  which case say so in a comment. **[GAME]**

### 3.4 Assertions

Assertions detect **programmer errors**. They are not for expected failures. TS draws a sharp
line: operating errors are expected and must be handled, whereas an assertion failure means
the code itself is wrong, and the only correct response is to crash. **[TS]**

- **MUST** assert function arguments, return values, preconditions, postconditions, and
  invariants. A function should not operate blindly on data it has not checked.
  **[TS, P10-5, P10-7]**
- **SHOULD** average at least **two assertions per function**. Both P10 and TS give this
  number. It is a density target, not a per-function gate, so do not add `assert(true)`;
  P10 explicitly says such padding defeats the rule. **[P10-5, TS]**
- **MUST** keep assertions free of side effects, so they can be disabled without changing
  behavior. **[P10-5]**
- **SHOULD** use **pair assertions**: for every property you care about, assert it on at least
  two different code paths. The standard example is validating data just before writing it
  and again right after reading it back. In a game: before serializing a save and after
  deserializing, before sending a message and after receiving it. **[TS]**
- **SHOULD** split compound assertions: `assert(a); assert(b);` instead of
  `assert(a and b);`. The failure message then identifies which one broke. To assert an
  implication, write `if (a) assert(b);`. **[TS]**
- **MUST** assert relationships between compile-time constants, using `comptime` blocks. These
  check the design before the program ever runs. **[TS]**
- **SHOULD** assert both the **positive space** (what you expect) and the **negative space**
  (what you do not expect). Bugs tend to live where data crosses between valid and invalid.
  Tests should likewise exercise invalid inputs, not just valid ones. **[TS]**
- **MAY** use a blatantly true assertion in place of a comment when the condition is critical
  and surprising. **[TS]**
- Assertions are a safety net, not a substitute for understanding. Build a mental model, encode
  it as assertions, explain it in comments, and use fuzzing or simulation to find mistakes in
  the model. A fuzzer can show that bugs exist, not that they don't. **[TS]**

```zig
comptime {
    // Documents and enforces a design assumption before anything runs.
    assert(entities_max <= std.math.maxInt(EntityIndex));
    assert(@sizeOf(Entity) <= 64);
}
```

**What happens on failure** is where this guide departs from P10, which prescribes a recovery
action (returning an error) when an assertion fails, and from a pure "always crash" reading of
TS. See section 11. In summary:

- Strict-zone assertions **MUST** be active in debug builds and in the headless fuzzer and
  test builds.
- Whether they remain active in shipped builds is a per-project decision that **MUST** be
  made explicitly and recorded here (see the project decisions at the end of this file).
  P10 notes that because assertions are side-effect free, they can be selectively disabled
  after testing in performance-critical code. If you disable any, disable the hottest ones
  first and keep the rest.
- **Zig-specific caution.** The standard library's `std.debug.assert` is checked only in
  modes that keep safety checks, and in the unsafe release modes the condition may be used by
  the optimizer as an assumption instead. This guide therefore **MUST** use its own
  `assert` function, defined in `base` (see the appendix), so that behavior is a conscious
  choice. Verify the exact behavior against the Zig version you use, since details have
  changed between releases.

### 3.5 Error handling

- **MUST** handle every error. TS cites a study of production failures in distributed
  data-intensive systems that found most catastrophic failures came from incorrect handling of
  non-fatal errors that the software had explicitly signaled. **[TS]**
- **MUST** check or explicitly discard return values. P10 makes the caller check every
  non-void return, allowing an explicit discard where the response to failure would be the
  same as to success, with a justification when it is not obvious. In Zig the compiler
  already forces this for error unions and unused values, so the practice is to write
  `_ = f();` deliberately and comment when the reason is not obvious. **[P10-7]**
- **SHOULD** prefer simple return types, since each added dimension spreads to every call
  site. TS ranks `void` over `bool` over `u64` over `?u64` over `!u64`. **[TS]**
- **MUST** distinguish *operating errors* (a missing file, a corrupt save, a lost device, a
  malformed network packet) from *programmer errors*. The first are handled with error
  returns. The second are assertions. **[TS]**
- **Strict zone only:** data from outside the strict zone (save files, level data, network
  messages, mods) is untrusted. Validate it at the boundary, in the decoders in `sim/api.zig`,
  with error returns, then assert inside. An assertion that a hostile or corrupt file can
  trigger is a bug in the validation. **[GAME]**

### 3.6 Memory

> "No memory may be dynamically allocated (or freed and reallocated) after initialization." [TS]

P10 gives the same rule (no dynamic allocation after initialization) and the same reasons:
allocator behavior is unpredictable for performance, and a notable class of bugs comes from
forgetting to free, using after free, or overrunning allocations. Living inside a fixed region
removes many of them and makes memory use easier to verify. TS adds that, in its experience,
designing for all memory usage up front also yields simpler and faster designs.

For games this needs a concrete structure **[GAME]**:

- **Strict zone only:** the simulation tick and everything it calls **MUST NOT** allocate from
  a general-purpose heap. All memory comes from regions sized at startup.
- **Permanent region:** world state, entity pools, lookup tables. Allocated once. Sized from
  the limits in section 3.2.
- **Level/scene region:** reset when a level or scene changes.
- **Frame scratch region:** a bump (arena) allocator reset at the end of every tick or frame.
  Use it for temporary lists, sort buffers, and formatted debug text. Nothing in it may
  outlive the frame. If something must, copy it into a permanent structure on purpose.
- **The relaxed zone** may use a general-purpose allocator for loading, tooling, and platform
  glue, but **SHOULD** perform that allocation during loading and initialization, not during
  steady-state frames.
- **SHOULD** have a debug-build allocator wrapper that counts allocations and asserts that none
  happen during a tick. That turns the rule from a convention into something a tool can
  check, which is the spirit of P10. **[P10-10, GAME]**
- **SHOULD** use handles (an index plus a generation counter) rather than raw pointers to
  refer to entities and resources stored in pools. Handles survive pool compaction, catch
  stale references, and serialize trivially. This is the game-development expression of
  P10's restriction on pointer use. **[P10-9, GAME]**
- Because memory is fixed, running out is a design error. Exceeding a pool's capacity is an
  assertion failure in development, with the fix being a capacity decision, not a fallback
  allocation. **[GAME]**

Memory-lifetime hygiene from TS also applies to the parts that remain:

- Group resource acquisition and release visually with blank lines, around `defer`, so leaks
  are easy to spot. **[TS]**
- Name allocators by their lifetime rule (`gpa`, `arena`, `frame_arena`) rather than a
  generic `allocator`, so the reader knows whether something must be freed. **[TS]**
- Initialize large structs in place through an out pointer instead of returning them by
  value, to avoid copies and stack growth. In-place initialization is viral: if one field is
  initialized in place, initialize the whole container that way. **[TS]**

### 3.7 Scope and state

- **MUST** declare variables at the smallest possible scope and keep the number of variables
  in scope small. **[P10-6, TS]**
- **SHOULD** compute or check a value near where it is used and not introduce variables before
  they are needed. TS names the failure mode POCPOU (place-of-check to place-of-use). **[TS]**
- **SHOULD NOT** duplicate state or hold aliases to it. Duplicates drift out of sync. **[TS]**
- **SHOULD** keep state mutation centralized: a parent function holds the state in locals and
  helpers compute what should change, rather than mutating directly. Keep leaf functions
  pure. **[TS]**
- **Strict zone only:** **MUST NOT** use mutable global state. The only global-like thing is
  the game state struct, passed explicitly. This is what makes the simulation replayable.
  **[GAME]**

### 3.8 Function size

- A function **SHOULD NOT** exceed **70 lines** (TS). P10 says roughly 60, one printed page.
  The reason for both is physical: a function that fits on one screen can be understood and
  verified as a unit. **[P10-4, TS]**
- Treat the limit as **MUST** in the strict zone and **SHOULD** in the relaxed zone. **[GAME]**
  A large state machine written as one `switch` is the usual exception, and the right response
  is to keep each arm trivial and delegate the work.
- A good shape is the inverse of an hourglass: few parameters, a simple return type, and the
  meaty logic in the middle. **[TS]**
- **SHOULD** make hot loops stand-alone functions that take primitive arguments and no
  `self`, so the compiler need not prove that fields can stay in registers and a reader can spot
  redundant computation. **[TS]**

### 3.9 Warnings and tooling

- **MUST** build with warnings at the strictest level available, from day one. **[P10-10, TS]**
- **MUST** treat a warning as a defect. P10 goes further: even if you believe a warning is a
  false positive, rewrite the code so the warning disappears, since many developers have been
  wrong about that assumption. **[P10-10]**
- **MUST** run `zig fmt`. **[TS]**
- **SHOULD** run the test suite and the simulation fuzzer (section 5) in CI on every change,
  in debug mode and in at least one optimized mode. P10 asks for static analysis every day. Zig
  has fewer third-party analyzers than C, so the compiler's own checks, safe build modes, and
  fuzzing carry more of the load. **[P10-10, GAME]**
- Compile-time configuration through build options **SHOULD** be minimal. P10's argument is
  that ten independent conditional-compilation switches could mean up to 2^10 variants of the
  program, each needing testing. The same arithmetic applies to build flags. **[P10-8]**

### 3.10 External events and the run loop

TS says to avoid doing things directly in reaction to external events. Instead, the program
runs at its own pace, which keeps control flow in your hands, lets you batch work, and makes it
easier to bound work per time period. **[TS]**

For a game this means **[GAME]**:

- Input callbacks, window events, network packets, and file-load completions **MUST** only
  enqueue into a fixed-capacity queue. They do not touch game state.
- The main loop drains these queues at a defined point in each frame, in a defined order, and
  translates input into sim commands (section 2.3).
- Queue overflow is handled deliberately: either assert (for queues that should never
  overflow) or drop with a counter (for lossy sources like mouse movement), and say which in
  a comment.
- Work per frame is bounded. If a frame has more simulation to catch up on than the cap
  allows, the game slows down visibly instead of spiraling.

## 4. Determinism and time

**[GAME]**, informed by TS's use of deterministic simulation (section 5.2). Determinism is not
required of every game, but the simulation in this codebase is written as if it is, because
it buys replay, reproducible bugs, and fuzzing for little extra cost.

- The simulation advances in **fixed ticks**. Rendering may run at any rate and interpolates or
  simply draws the latest state. Be aware that a fixed tick decoupled from the display rate
  can cause visual aliasing, and that this is a rendering concern to solve in the app.
- **Strict zone only:** simulation code **MUST NOT** read wall-clock time, read hardware state,
  allocate nondeterministically, or iterate over anything whose order is unspecified. Time
  inside the sim is a tick counter.
- **Strict zone only:** all randomness **MUST** come from one explicitly seeded PRNG stored in
  the game state. Separate streams (gameplay, cosmetic effects) are fine so long as each is
  seeded and stored.
- The tick function **SHOULD** have the shape `tick(state, inputs, outputs) -> void`, where
  `inputs` holds that tick's commands and `outputs` receives that tick's events (section 2.3).
  Recording `inputs` per tick plus the seed is then a complete replay.
- **SHOULD** compute a cheap hash of the state periodically in debug builds. Replaying the same
  inputs must produce the same hashes. A mismatch is a determinism bug caught near its
  cause.
- Floating-point results can differ across compilers, optimization levels, and CPU
  architectures. If you need cross-platform determinism (netcode, shared replays), this is a
  real risk and needs its own decision: fixed-point math, restricted float operations, or
  limiting determinism to one platform. Record the decision under project decisions.
- **MUST** carry units in the names of time-like values (`ticks`, `ms`, `seconds`) and not mix
  them. See naming below.

## 5. Testing

### 5.1 Tests

- **MUST** test with invalid inputs and with data that crosses the boundary between valid and
  invalid, in addition to valid data. **[TS]**
- **SHOULD** start each test with a short description of its goal and method. **[TS]**
- **SHOULD** write tests as small pure-function tests where possible; keeping leaf functions
  pure (3.7) is what makes that cheap. **[TS]**

### 5.2 Simulation fuzzing

TigerBeetle runs its production code inside a deterministic simulator that stubs out the
non-deterministic parts, is seeded, and can replay any failure from the seed and commit.
It can also speed time up arbitrarily, and TigerBeetle calls assertions a force multiplier when
combined with fuzzing. **[TS, TigerBeetle docs]**

A sim written to section 4 can do the same, at a smaller scale **[GAME]**:

- Provide a headless build of `sim` and `base` that links no `app` code.
- Provide a fuzz driver in `tools/` that uses the sim only through `sim/api.zig`. It takes a
  seed, generates random commands for many thousands of ticks, runs the tick function with all
  assertions enabled, and exits non-zero on failure.
- Print the seed on failure. A bug report is a seed plus a commit.
- Run many seeds in CI. Scale the count up overnight.
- Prefer a single-threaded sim. Multithreading inside the tick makes replay far harder, so
  confine threads to the relaxed zone and to clearly isolated, deterministic work.

As TS cautions: do not use the fuzzer as a substitute for thinking. Build the model first,
write the assertions, then let the fuzzer test your understanding.

## 6. Performance

- **SHOULD** think about performance during design, not only during profiling. TS argues the
  biggest wins come from design decisions, which is exactly when you cannot yet measure. **[TS]**
- **SHOULD** make back-of-the-envelope estimates for the resources that matter, with their
  bandwidth and latency characteristics, before building. For games the usual resources are
  CPU time per tick, memory bandwidth and cache behavior, GPU time, and (if relevant) network
  and disk. Aim to be roughly right. **[TS]**
- **SHOULD** optimize the slowest resource first, adjusted for how often it is used. A cache
  miss that happens a million times can outweigh a rare disk read. **[TS]**
- **SHOULD** batch. Give the CPU large uniform chunks of work: iterate over arrays of plain
  data instead of chasing pointers through objects. **[TS]**
- **SHOULD** separate the control plane from the data plane: decision logic runs per entity and
  rarely, bulk processing runs over arrays and often. **[TS]**
- **SHOULD** be explicit and not depend on the optimizer for things that matter. **[TS]**
- Measure before optimizing a specific hot spot. Design-level thinking does not replace
  profiling. **[GAME]**

## 7. Developer experience

### 7.1 Naming

- **MUST** use `snake_case` for functions, variables, and file names. **[TS]** Types use Zig's
  `PascalCase` and constants follow the Zig style guide for the rest. **[TS]**
- **SHOULD** pick nouns and verbs carefully, since names carry the mental model. Spend the
  time. **[TS]**
- **SHOULD NOT** abbreviate, except for conventional short names for primitive integers in
  small math or sorting code. **[TS]**
- **MUST** use proper capitalization for acronyms (`AABB`, not `Aabb`). **[TS]**
- **MUST** put units and qualifiers in names, last, ordered from most to least significant
  word, so related names group and line up. `latency_ms_max`, not `max_latency_ms`.
  **[TS]** For games, `speed_units_per_tick_max`, `cooldown_ticks`, `fade_seconds`. This is
  the cheapest defense against unit mix-ups.
- **SHOULD** prefer nouns over adjectives or participles for state names, because they can be
  used directly in documentation and compose into derived names (`queue_max`). **[TS]**
- **SHOULD NOT** reuse a name for two meanings. **[TS]**
- **SHOULD** choose related names of equal length when it helps (`source`/`target`), so related
  expressions line up visually. **[TS]**
- Helper and callback names **SHOULD** be prefixed with the calling function's name to show
  call history (`read_sector`, `read_sector_callback`), and callbacks go last in parameter
  lists. **[TS]**
- Where two arguments of the same type could be swapped (two `u32` ids), **MUST** use an
  options struct so call sites are labeled. Dependencies like allocators are passed
  positionally, from most general to most specific. **[TS]**
- **SHOULD** pass options explicitly at call sites instead of relying on library defaults, so a
  future change to the defaults cannot silently change behavior. **[TS]**

### 7.2 Layout and formatting

- **MUST** run `zig fmt`. 4-space indentation. **[TS]**
- **MUST** keep lines to 100 columns or fewer, with no exceptions. The reason is physical: two
  copies of the code fit side by side. To wrap, add a trailing comma and let `zig fmt` do it.
  **[TS]**
- **SHOULD** order a file so the most important things come first, with `main` or the primary
  entry point at the top. In a struct, order fields, then types, then methods. **[TS]**
- **SHOULD** use braces on `if` statements unless the whole statement fits on one line, as
  defense against "goto fail"-style bugs. **[TS]**

### 7.3 Comments and commits

- Comments **SHOULD** explain why and how, not restate the code. **[TS]**
- Comments are sentences: capital letter and a full stop, with a space after the slashes.
  End-of-line comments may be short phrases. **[TS]**
- Commit messages **SHOULD** describe what changed and why, since they are visible in
  `git blame` and pull request descriptions are not. **[TS]**

## 8. Dependencies and tooling

TigerBeetle has a zero-dependency policy beyond the Zig toolchain, and prefers one standard
toolbox, writing scripts in Zig instead of shell. **[TS]** For a game, that is too strict as
written (section 11), so:

- **SHOULD** keep dependencies few, small, and understood well enough to debug. Prefer
  libraries you can vendor and read over large frameworks.
- **MUST** keep `base` and `sim` free of third-party, platform, and graphics dependencies
  (section 2.2).
- **SHOULD** write build and asset scripts in Zig where practical. They then run on every
  platform the game builds on, with type checking. **[TS]**
- Adding a new tool has a real cost in learning and maintenance. **SHOULD** justify each one.
  **[TS]**

## 9. Review checklist

Use this on any change that touches `base` or `sim`, or the code in `app` that talks to them.

1. Does every new loop and queue have a named limit, with an assertion?
2. Is there any recursion, hidden allocation, wall-clock read, I/O, or global mutable state in
   the strict zone?
3. Do new functions assert their inputs and outputs, and do save/load or send/receive pairs
   assert on both sides?
4. Are units in every time-, distance-, and size-like name?
5. Can the change run in the headless fuzzer? Does the fuzzer cover it?
6. Is untrusted data validated by a decoder in `sim/api.zig`, and not asserted on?
7. Are there new compile-time constants whose relationships should be `comptime`-asserted?
8. Does gameplay logic live in `sim`, with `app` only translating?
9. Does everything crossing the boundary go through `sim/api.zig`: commands in, events and
   `*const` state reads out, with no callbacks into the app and no writes to sim state?
10. Do `base` and `sim` import only what section 2.2 allows?
11. Any new warning, or new build option?
12. Does the comment on anything surprising say why?

## 10. Adoption order

If you are retrofitting an existing project, do not do it all at once.

1. Turn on strict warnings and `zig fmt` in CI. Add the project's own `assert` to `base`.
2. Split the code into `base/`, `sim/`, and `app/`. Declare them as modules in `build.zig` and
   enforce the import rules from section 2.2.
3. Gather simulation state into one struct with one `tick` and one seeded PRNG.
4. Create `sim/api.zig` with commands, events, and the `tick` signature. Move input handling
   to commands and presentation triggers to events.
5. Add memory regions and capacity constants with `comptime` assertions.
6. Add the debug allocation counter and assert no allocation during `tick`.
7. Bound every loop and queue. Remove recursion from the strict zone.
8. Build the headless fuzz driver and record-and-replay.
9. Rename toward unit-suffixed names opportunistically, as you touch code.

## 11. Departures from upstream

| Topic | Upstream | This guide | Why |
|---|---|---|---|
| Strictness | Applies to all code | Strict zone (`base`, `sim`) strict, relaxed zone (`app` and above) relaxed | Games fail cheaply compared to databases and spacecraft, and tooling and prototypes need speed. |
| Assertion failure | P10: take an explicit recovery action. TS: crash. | Crash in debug, fuzz, and test. Shipped behavior is an explicit project decision. | The two sources disagree, and a shipped game may prefer to write a crash report and return to a menu. |
| Assertions in release | P10: may be disabled after testing. TS: keeps them on (assertion density is central to its approach). | Own `assert`, enabled or not per project decision. | Zig's standard `assert` behaves differently across build modes, so the choice should be explicit. |
| Function length | P10: about 60 lines. TS: hard limit of 70. | 70, MUST in the strict zone, SHOULD elsewhere, with a state-machine exception | Large `switch` statements are common in games and often clearer whole. |
| Function pointers | P10: not permitted | Allowed in the relaxed zone and at platform callbacks. Not used in the strict zone, which emits events instead of calling back. | Platform libraries use callbacks, and the analysis argument matters most inside the sim. |
| Pointer depth | P10: at most one level of dereference | Prefer handles over pointers in the strict zone, no hard depth limit | Zig's type system and slices already address many of P10's concerns. |
| Static analysis | P10: multiple analyzers daily | Compiler checks, module-graph import rules, safe build modes, fuzzing, tests in CI | The Zig ecosystem has fewer analyzers than C. |
| Preprocessor | P10: restrict it | Not applicable, and the build-flag explosion argument is applied to build options | Zig has no preprocessor. |
| Dependencies | TS: zero beyond Zig | Zero in `base` and `sim`. Few, small, vendorable in the relaxed zone. | A game needs a platform layer at the very least. |
| Technical debt | TS: zero-debt policy | Not adopted | Prototypes get thrown away. Debt in the strict zone is still discouraged. |
| Dynamic memory | Both: none after init | Same in the strict zone, with relaxed-zone exceptions during loading | Asset loading and tooling genuinely need dynamic memory. |
| Determinism | TS: central to the database | Adopted as a design target for the simulation | Cheap in a game sim if planned up front, and valuable for testing. |

## Appendix: Zig sketches

These show intent. Standard-library details change between Zig releases, so check them against
your version, and in particular check the allocator interface, which has been revised more
than once.

### Project assertion (`base/assert.zig`)

```zig
// Unconditional in every build mode. Callers who want a release-mode opt-out should add
// a build option here, deliberately, and record the decision below.
pub fn assert(ok: bool) void {
    if (!ok) @panic("assertion failed");
}
```

Because this is an ordinary function, it also works inside `comptime` blocks, where a failing
condition becomes a compile error.

### Handles into a pool

```zig
pub const EntityIndex = u16;
pub const entities_max: u32 = 4096;

pub const EntityHandle = struct {
    index: EntityIndex,
    generation: u16,
};

// On lookup, assert pool.generation[handle.index] == handle.generation. A mismatch means
// someone kept a handle to an entity that has since been destroyed.
```

### The sim API (`sim/api.zig`)

```zig
const std = @import("std");
const base = @import("base");
const assert = base.assert;

pub const GameState = @import("state.zig").GameState;

pub const commands_per_tick_max = 16;
pub const events_per_tick_max = 256;

comptime {
    assert(commands_per_tick_max <= std.math.maxInt(u8));
    assert(events_per_tick_max <= std.math.maxInt(u16));
}

/// What a player intends. The app maps devices to these.
pub const Command = union(enum) {
    move: struct { player: PlayerIndex, direction: Direction },
    fire: struct { player: PlayerIndex },
};

pub const TickInputs = struct {
    commands: [commands_per_tick_max]Command,
    command_count: u8,
};

/// What happened this tick that the presentation should react to.
pub const Event = union(enum) {
    entity_died: struct { entity: EntityHandle, kind: EntityKind },
    sound: struct { kind: SoundKind, position: base.Vec2 },
};

pub const TickOutputs = struct {
    events: [events_per_tick_max]Event,
    event_count: u16,
};

pub fn tick(state: *GameState, inputs: *const TickInputs, outputs: *TickOutputs) void {
    assert(state.tick_count < std.math.maxInt(u64));
    assert(inputs.command_count <= commands_per_tick_max);
    // Apply commands, advance systems in a fixed order, append events to `outputs`.
    // No allocation, no I/O, no wall-clock time.
    state.tick_count += 1;
}

/// Validates untrusted bytes. Returns an error for bad data; never asserts on it.
pub fn level_decode(bytes: []const u8, target: *LevelDefinition) !void {
    // ...
}
```

`PlayerIndex`, `Direction`, `EntityKind`, `SoundKind`, and `LevelDefinition` are sim types,
re-exported here like `GameState`. `level_decode` takes an out pointer because a level
definition may be large (section 3.6).

### Allocation guard (described, not coded)

Wrap the allocator given to the app and to the sim's scratch region in a small type that counts
calls. In debug builds, record the count before `tick`, run it, and assert the count is
unchanged. Implement it against your Zig version's allocator interface.

## Project decisions (fill these in)

- Source root (where `base/`, `sim/`, `app/` live): src/
- Assertions in shipped builds: off
- Determinism target: not required
- Number representation in the sim: depends
- How the app reads sim state for rendering: direct `*const`
- Fuzz seeds per CI run: TBD
- Memory budget per region (permanent / level / frame): TBD
- Rules from this document waived for this project, with reasons: ______
