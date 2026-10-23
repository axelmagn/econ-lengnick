# AGENTS.md

Instructions for AI coding agents working in this repository. Read this file completely before
writing or changing any code. The full style guide is `STYLE.md`. This file is the short version
plus the procedure for applying it.

## 0. Setup you must fill in once (humans)

Agents: if any value below is still a placeholder, say so in your first reply and ask rather
than guessing.

- Strict zone: `src/base/`, `src/sim/` (placeholder: confirm the source root)
- Relaxed zone: `src/app/`, `src/tools/`, `src/scratch/` (placeholder: confirm)
- Sim API: `src/sim/api.zig`
- Project assert: `src/base/assert.zig`
- Build: `zig build`
- Test: `zig build test`
- Format check: `zig fmt --check src`
- Fuzz (headless simulation): `zig build fuzz -- <seed>` (placeholder: change or delete)

## 1. How to work here

Follow this order every time. Do not skip steps because the task looks small.

1. **Read `STYLE.md`** sections 2 through 4 and any section relevant to the task. Do this
   before opening the files you plan to change.
2. **Decide where the code belongs.** If it can change the outcome of a tick, it belongs in
   `sim`, even if the request mentions input, UI, or rendering. Shared deterministic utilities
   belong in `base`. Everything that touches the outside world belongs in `app`.
3. **Classify each file you will touch:** strict zone (`base/`, `sim/`) or relaxed zone
   (everything else). The strict rules are much stricter. If unsure, treat the file as strict.
4. **If the change crosses between `app` and `sim`, read `sim/api.zig` first.** That file is
   the whole boundary.
5. **Look at neighboring code** and match its existing patterns for naming, assertions, and
   structure. Consistency with the surrounding code is part of the style.
6. **Make the smallest change that solves the task.** Do not reformat, rename, or refactor
   code you were not asked to touch.
7. **Run the checks in section 5.** Fix what they report.
8. **Review your own diff against the checklist in section 4**, line by line, before
   reporting that you are done.
9. **Report** what you changed, any rule you could not satisfy, and anything you were unsure
   about (section 7).

## 2. Hard rules (summary of `STYLE.md`)

These are the rules agents break most often. Unless marked "everywhere", they apply to the
**strict zone** (`base/` and `sim/`).

### Imports
- `base` imports only `std`, `builtin`, and files inside `base/`.
- `sim` imports only `std`, `builtin`, `base`, and files inside `sim/`.
- Relaxed-zone code reaches the sim only through `sim/api.zig` (the `sim` module). Never
  import another `sim` file from outside `sim/`.
- Do not add dependencies to the `base` or `sim` modules in `build.zig`.

### The sim/app boundary
- **Gameplay logic goes in `sim`.** `app` translates input to commands and events to
  presentation. It does not decide what happens.
- Every type or function that crosses the boundary is declared in, or re-exported from,
  `sim/api.zig`. If you need a new one, add it there.
- **Input reaches the sim only as commands** defined in `sim/api.zig`, never as key codes,
  button IDs, or device events. Debug tools and cheats also issue commands.
- **The sim reports to the app only through the event buffer** in `TickOutputs`. Never pass a
  callback or function pointer into the sim.
- **The app reads sim state through `*const` only.** It never writes sim state, not even from
  debug UI.
- **The sim does no I/O.** The app reads bytes. The sim decodes and validates them with the
  decoders in `sim/api.zig`.
- The sim refers to assets by its own enums or IDs (`SoundKind.footstep`), never by GPU
  handles, audio buffers, or file paths. The app maps IDs to resources.

### Memory
- **No heap allocation in the strict zone after initialization.** Do not call an allocator
  inside `tick` or anything it calls. Use the permanent, level, or frame-scratch regions.
- Do not add `ArrayList`, `HashMap`, or any growable container to the strict zone. Use
  fixed-capacity containers sized by a named `*_max` constant.
- Refer to pooled things by **handle** (index plus generation), not by pointer.

### Control flow and limits
- **No recursion in the strict zone.** Use an explicit fixed-capacity stack.
- **Every loop with a variable iteration count has a named upper bound and an `assert`** on it.
- **Every queue, buffer, and pool has a fixed named capacity.** Never an unbounded fallback.
- Prefer simple nested `if`/`else` over compound boolean conditions. Write conditions in the
  positive form (`index < count`).

### Assertions (everywhere)
- Use the project's `assert` from `base`, **never `std.debug.assert`**.
- Assert function arguments, return values, preconditions, postconditions, and invariants.
  Target at least two assertions per function with real logic. Never add `assert(true)` or
  similarly empty assertions to hit a number.
- **Split compound assertions:** write `assert(a); assert(b);`, never `assert(a and b);`.
- Assertions have **no side effects**.
- Use `comptime` assertions for relationships between constants and for struct sizes.
- When data is written out (save, network, replay) and read back, **assert on both sides**.

### Errors (everywhere)
- Handle every error. Do not write `catch unreachable`, empty `catch {}`, or discard an error
  with `_ =` unless a comment on that line says why it is safe.
- **Data from outside the strict zone** (files, network, mods, user input) is validated by a
  decoder in `sim/api.zig` and rejected with an error. **Never assert on untrusted data.**
- Assertions are only for programmer errors, meaning conditions that can only be false if
  the code is wrong.

### Determinism
- **No wall-clock time, no OS calls, no I/O, no unseeded randomness, and no iteration over
  unordered containers in the strict zone.** Time is a tick count. Randomness comes from the
  seeded PRNG stored in the game state.
- **No mutable global state in the strict zone.** Pass the game state explicitly.

### Names and numbers (everywhere)
- `snake_case` for functions, variables, and files. `PascalCase` for types.
- **Units go in names, last**, from most to least significant word: `delay_ticks`,
  `speed_units_per_tick_max`. Never mix ticks, milliseconds, and seconds in one expression
  without an explicit conversion.
- Use sized integers (`u32`, `i16`). Avoid `usize` except at the point of indexing.
- Keep `index`, `count`, and `size` conceptually distinct, and convert between them
  deliberately.
- Do not abbreviate names. No `idx`, `cnt`, `tmp`, `ctx` unless the project already uses them
  (check first).
- Use `@divExact`, `@divFloor`, or a named ceiling-division helper instead of bare `/` on
  integers.
- Where two parameters share a type and could be swapped, use an options struct.
- Pass options explicitly at call sites. Do not rely on library defaults.

### Shape and format (everywhere)
- Functions at most **70 lines** (strict zone: hard limit).
- Lines at most **100 columns**. Run `zig fmt`.
- Braces on every `if` unless the whole statement fits on one line.
- Declare variables in the smallest scope, as close to first use as possible.
- Do not duplicate state or keep aliases to it.
- Comments are full sentences that say **why**. Do not write comments that restate the code.

## 3. Things agents tend to do that this project forbids

If you catch yourself doing any of these, stop and redo it the project's way.

- Putting gameplay logic in `app` because that is where the input or UI code is.
- Changing sim state directly from `app`, including from debug UI or a cheat key.
- Passing raw input (key codes, mouse buttons) into the sim instead of a command.
- Passing a callback, function pointer, or app-side type into the sim.
- Reading a file or doing other I/O inside `sim` "just for this one asset".
- Importing a `sim` file other than `api.zig` from `app`, `tools`, or `scratch`.
- Adding a module dependency to `base` or `sim` in `build.zig`.
- Reaching for a dynamic container because it is convenient. Choose a fixed capacity.
- Adding a fallback allocation "just in case" a pool fills up. A full pool is a design error
  that should trip an assertion.
- Adding a helper that quietly allocates, and calling it from the strict zone.
- Using `std.time`, `std.crypto.random`, or a PRNG seeded from the clock inside the strict
  zone.
- Making an assertion pass by loosening it, or deleting an assertion that fires. A firing
  assertion is information. Find the bug.
- Swallowing an error to make the compiler or a test quiet.
- Adding a dependency, build option, or tool without being asked.
- Reformatting or renaming unrelated code in the same change.
- Silencing a compiler warning instead of rewriting the code so the warning does not occur.
- Writing "TODO" or leaving a temporary hack in the strict zone.
- Inventing a constant that is not derived from a named limit.
- Marking work as done without running the checks.

## 4. Self-review checklist (do this before saying "done")

Go through your diff and answer each question. If an answer is "no" or "not sure", fix it or
report it.

1. Is every piece of gameplay logic I added in `sim`, not `app`?
2. Did I classify each changed file as strict or relaxed, and apply the matching rules?
3. Do `base` and `sim` still import only what section 2 allows? Does relaxed code reach the
   sim only through `sim/api.zig`?
4. Does everything crossing the boundary go through `sim/api.zig`: commands in, events and
   `*const` reads out, no callbacks, no app writes to sim state?
5. Does any strict-zone code I wrote or touched allocate, recurse, do I/O, or read the clock
   or OS?
6. Does every new loop have a named bound with an assertion, and every new buffer a named
   capacity?
7. Does every new function with logic assert its inputs and outputs? Are compound assertions
   split?
8. Where data is serialized or sent, is there a matching assertion on the read or receive side?
9. Is untrusted data validated by a decoder with error returns, and never asserted on?
10. Are units in the name of every new time-, distance-, rate-, or size-like value?
11. Did I handle or deliberately discard every error, with a comment where the reason is not
    obvious?
12. Are there new constant relationships that should be `comptime`-asserted?
13. Are all functions 70 lines or fewer and all lines 100 columns or fewer?
14. Did I stay within the task? Is every changed line necessary?
15. Do my comments explain why?

## 5. Mechanical checks

Run these after every change and report the result. If a command does not exist or fails
for a reason unrelated to your change, say so. Do not hide it.

```
zig fmt --check src
zig build
zig build test
```

Then run these searches and justify or remove every hit. Adjust `src/` if the source root
differs.

```
# Imports out of base: anything other than std, builtin, or a file inside base/.
grep -rnE '@import\(' src/base \
  | grep -vE '@import\("(std|builtin)"\)|@import\("[a-z0-9_/]+\.zig"\)'

# Imports out of sim: anything other than std, builtin, base, or a file inside sim/.
grep -rnE '@import\(' src/sim \
  | grep -vE '@import\("(std|builtin|base)"\)|@import\("[a-z0-9_/]+\.zig"\)'

# Relaxed code reaching past the sim API.
grep -rnE '@import\("[^"]*sim/[a-z0-9_]+\.zig"\)' src --include='*.zig' \
  | grep -vE '^src/sim/'

# Banned in the strict zone.
grep -rnE 'std\.debug\.assert|ArrayList|HashMap|\.append\(|catch unreachable' src/base src/sim
grep -rnE 'std\.(time|fs|net|Thread)|std\.crypto\.random' src/base src/sim

# Lines over 100 columns, anywhere.
find src -name '*.zig' -exec awk 'length > 100 {print FILENAME": "FNR": "length}' {} +
```

The import searches are an allow-list: a hit means an import that is not on the list. The
relative-path pattern rejects any path containing `..`, so a file cannot climb out of its
directory.

Passing the checks is necessary, not sufficient. They cannot see most of the rules. The checklist
in section 4 covers the rest.

## 6. When you cannot comply

Never silently deviate from the style. If a rule seems to conflict with the task, a library's
API, or an existing file:

1. Make the compliant choice if one exists, even if it is less convenient.
2. If none exists, make the minimal deviation, and put a comment at that spot starting with
   `STYLE EXCEPTION:` that states which rule, and why.
3. List every exception in your final report, with file and line.
4. Do not "fix" existing code that already violates the style unless asked. Mention it in
   your report instead.

If the task itself asks for something the style forbids, say so before starting, state the
tradeoff briefly, and ask which to prefer. Do not pick for the human.

If `STYLE.md` and this file disagree, follow `STYLE.md` and point out the disagreement.

If you are unsure whether code belongs in `base`, `sim`, or `app`, or which of two rules
applies, ask. A short question is cheaper than a wrong guess in the strict zone.

## 7. How to report

Keep the final report short and in this form:

- **Changed:** what and where, in one or two sentences.
- **Checks:** which commands you ran and whether each passed.
- **Exceptions:** each `STYLE EXCEPTION`, or "none".
- **Concerns:** anything that you were unsure about, any existing violations you noticed, and
  anything that you could not verify.

Do not claim a check passed unless you ran it. Do not claim the code follows the style because
it "looks right"; say which checks you ran.

## 8. Writing new code: patterns to copy

### Sim logic

When adding logic in `sim`, shape it like this unless there is a reason not to:

```zig
/// Applies damage to one entity. Returns true if the entity died this call.
fn damage_apply(state: *GameState, target: EntityHandle, amount_hp: u16) bool {
    assert(entity_is_alive(state, target)); // Callers must filter dead targets first.
    assert(amount_hp > 0);

    const entity = entity_get(state, target);
    const hp_before = entity.hp;
    entity.hp -|= amount_hp;

    assert(entity.hp <= hp_before);
    return entity.hp == 0;
}
```

What to notice: preconditions at the top, units in the name (`amount_hp`), a postcondition
before return, a comment saying *why* the first assertion exists, a small function with one
job, and no allocation, no clock, and no global state.

### A new player action

Adding something the player can do touches three places, in this order:

1. Add a variant to `Command` in `sim/api.zig`.
2. Handle that variant inside the sim's tick. Emit an `Event` if the presentation should react.
3. In `app`, map the device input to the new command, and react to any new event.

The examples are illustrative: match the real names and helpers in the codebase rather than
copying these literally.

## 9. For humans maintaining this file

Agents follow short, specific, checkable instructions much better than long principles. When
agents keep breaking a rule, do not add emphasis. Instead:

- Move the rule up into section 2 and make it concrete (a banned call, a required pattern).
- Add a mechanical check for it to section 5 if one can be written.
- Add the mistake to section 3 as a specific forbidden behavior.
- Delete rules that no longer matter. A shorter file is followed more reliably.

Prefer enforcing import rules through the module graph in `build.zig` (see `STYLE.md` section
2.2). A compile error is followed every time; a written rule is not.
