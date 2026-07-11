# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository is the **devcontainer infrastructure** for developing the Claude Code configuration project at `~/.claude`. It contains no application code itself — the scripts and tests being developed live at `~/.claude`, which is mounted into the container at `/root/.claude`.

Open `multiple.code-workspace` in VS Code to work with both directories (this infra + the config project) as a multi-root workspace.

## Commands

All development commands target the `~/.claude` project (mounted at `/root/.claude`). The permitted task runner commands are:

```bash
# Run tests
uv run invoke test                      # all tests via invoke
uv run pytest --directory /root/.claude # direct pytest

# Lint and style
uv run invoke lint
uv run invoke style

# Clean build artifacts
uv run invoke clean

# Other task groups
uv run invoke dist
uv run invoke path
```

To run a single test:
```bash
uv run pytest tests/path/to/test_file.py::TestClass::test_method
```

## Architecture

### Container setup (`Dockerfile` + `compose.yml`)

Built from `futureys/claude-code-python-development` with `git` and GitHub CLI (`gh`) added on top. Key volume mounts in `compose.yml`:

| Mount | Purpose |
|---|---|
| `.:/workspace` | This infrastructure repo |
| `~/.claude:/root/.claude` | The config project being developed |
| `~/.claude.json:/root/.claude.json` | Claude Code auth |
| `uv-cache:/root/.cache/uv` | Persistent uv package cache |

The `.venv` inside the container is kept separate from the host via an anonymous volume (`/workspace/.venv`).

### Permissions (`.claude/settings.json`)

- **Allowed**: `uv run invoke <clean|dist|lint|path|style|test>*`, `uv run pytest*`
- **Denied**: `git push main*`, `rm*`, `Read(**/.env)`

### Dependabot

Configured in `.github/dependabot.yml` to check for devcontainer updates weekly.
