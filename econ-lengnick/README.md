# Sokol C Sample

A lightweight, simple starter template for C using [sokol](https://github.com/floooh/sokol) and [Nuklear](https://github.com/Immediate-Mode-UI/Nuklear). It draws a triangle alongside a Nuklear GUI control panel.

No CMake or build systems, just scripts.

## Quickstart

1. Fetch dependencies:

```bash
# Bash (Linux / macOS / WSL / Git Bash)
./bin/fetch-deps.sh

# PowerShell (Windows)
.\bin\fetch-deps.ps1
```

2. Run the app:

```bash
# Bash
./bin/run.sh

# PowerShell
.\bin\run.ps1
```

**NOTE**: for reproducible builds, pass `--pin` when fetching dependencies to capture exact commit hashes into `deps.lock`.

## Build Scripts

### Fetching & Pinning Dependencies

Fetch Sokol, Nuklear, and `sokol-shdc`:

```bash
# Bash
./bin/fetch-deps.sh          # fetch dependencies
./bin/fetch-deps.sh --pin    # fetch and capture commit hashes to deps.lock

# PowerShell
.\bin\fetch-deps.ps1         # fetch dependencies
.\bin\fetch-deps.ps1 -Pin    # fetch and capture commit hashes to deps.lock
```

When `deps.lock` is present, `config.sh` and `config.ps1` will automatically load the pinned commit hashes.

### Building

Build using `bin/build.sh` or `bin/build.ps1`:

```bash
# Bash
./bin/build.sh              # build native binary
./bin/build.sh --web        # build web assembly target
./bin/build.sh --clean      # clean build directory

# PowerShell
.\bin\build.ps1             # build native binary
.\bin\build.ps1 -Web        # build web assembly target
.\bin\build.ps1 -Clean      # clean build directory
```

### Running

Build and run in one step using `bin/run.sh` or `bin/run.ps1`:

```bash
# Bash
./bin/run.sh                    # build and run native binary
./bin/run.sh --web              # build and serve web target
./bin/run.sh --web --port 3000  # build and serve on a custom port

# PowerShell
.\bin\run.ps1                   # build and run native binary
.\bin\run.ps1 -Web              # build and serve web target
.\bin\run.ps1 -Web -Port 3000   # build and serve on a custom port
```

## Project Layout

- `src/main.c`: Application logic & Nuklear UI
- `shaders/`: GLSL shaders and generated header code
- `bin/`: Build, run, fetch-deps, and config scripts (Bash and PowerShell)
- `deps/`: Downloaded dependencies (`deps/include/` for headers, `deps/tools/` for `sokol-shdc`)
- `deps.lock`: Optional lockfile containing pinned commit hashes


## AI Usage Disclosure

This project was made with the assistance of LLM agents.  It contains both handcrafted and generated code.  I understand if this bums you out, and it's cool if you only want to use handcrafted source.  I decided that life is too short for writing boilerplate and windows build scripts by hand.
