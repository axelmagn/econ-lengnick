# Sokol C Sample

A lightweight, simple starter template for C using [sokol](https://github.com/floooh/sokol) and [Nuklear](https://github.com/Immediate-Mode-UI/Nuklear). It draws a triangle alongside a Nuklear GUI control panel.

No CMake or build systems, just scripts.

## Getting Started

### Prerequisites

- **C Compiler**: `clang` (default) or `gcc`
- **Utilities**: `curl` & `tar` (for auto-downloading dependencies)
- **Linux**: OpenGL and X11 dev libraries (`libgl1-mesa-dev`, `libx11-dev`, `libxi-dev`, `libxcursor-dev`)
- **macOS**: Xcode Command Line Tools
- **Windows**: `clang` / LLVM or GCC with PowerShell 5.1+
- **Web target (optional)**: [Emscripten](https://emscripten.org/) (`emcc`) & `python` / `python3`

### Quickstart

Run the app right away:

```bash
# Bash (Linux / macOS / WSL / Git Bash)
./bin/run.sh

# PowerShell (Windows)
.\bin\run.ps1
```

Dependencies (Sokol, Nuklear, and `sokol-shdc`) will auto-fetch on the first run. **NOTE**: for reliable builds, consider doing one of the following:

1. configure a recent commit hash in `config.sh` / `config.ps1` to make sure you get the same files every time.
2. vendor `deps/` by removing it from `.gitignore` and checking it into git.

## Usage

### Building

Build using `bin/build.sh` or `bin/build.ps1`:

```bash
# Bash
./bin/build.sh              # build native binary
./bin/build.sh --web        # build web assembly target
./bin/build.sh --fetch-deps # (re)fetch sokol and nuklear
./bin/build.sh --clean      # clean build directory

# PowerShell
.\bin\build.ps1             # build native binary
.\bin\build.ps1 -Web        # build web assembly target
.\bin\build.ps1 -FetchDeps  # (re)fetch sokol and nuklear
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
- `bin/`: Build, run, and config scripts (Bash and PowerShell)
- `deps/`: Downloaded Sokol & Nuklear headers + `sokol-shdc`


## AI Usage Disclosure

This project was made with the assistance of LLM agents.  It contains both handcrafted and generated code.
