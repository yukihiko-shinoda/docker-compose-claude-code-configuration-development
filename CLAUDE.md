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

Built directly `FROM node:${DOCKER_IMAGE_TAG_NODE}` (Node is needed for npm-installed tooling), with
`uv`/`uvx` copied in from the pinned `ghcr.io/astral-sh/uv` image via multi-stage `COPY --from`.
The Node tag, uv version, and Claude Code version are all Dockerfile `ARG`s with defaults, but
`compose.yml` re-declares them as *required* build args (`${VAR:?err}`) sourced from the shell
environment — so a compose build needs an `.env` file (or exported vars) setting
`DOCKER_IMAGE_TAG_NODE`, `VERSION_UV`, and `VERSION_CLAUDE_CODE`, even though the Dockerfile alone
would build fine without one. Claude Code is installed via the native installer, plus `git`, GitHub
CLI (`gh`), a version-pinned `skill-validator` binary, and `markdownlint-cli2` installed globally via
npm (lints `SKILL.md` and Markdown files respectively; version bumps for both are manual, not
tracked by Dependabot). The former `futureys/claude-code-python-development` base image is no longer
used — its settings (WORKDIR, `UV_LINK_MODE`, apt packages, SHELL, PATH, native Claude Code install,
`DISABLE_AUTOUPDATER`, ENTRYPOINT/CMD) are replicated verbatim in this repo's `Dockerfile`, which is
now self-contained. Key volume mounts in `compose.yml`:

| Mount | Purpose |
|---|---|
| `.:/workspace` | This infrastructure repo |
| `~/.claude:/root/.claude` | The config project being developed |
| `~/.claude.json:/root/.claude.json` | Claude Code auth |
| `uv-cache:/root/.cache/uv` | Persistent uv package cache |

The `.venv` inside the container is kept separate from the host via an anonymous volume (`/workspace/.venv`).

### Editor setup (`.devcontainer/`)

Uses the devcontainers "Existing Docker Compose (Extend)" pattern: `devcontainer.json`'s
`dockerComposeFile` list combines the root `compose.yml` with `.devcontainer/compose.yml` (the
latter just re-mounts `.:/workspace` and overrides the command to `sleep infinity` so the container
stays up). `workspaceFolder` is `/workspace`.

On save, Python files are auto-formatted and import-sorted by Ruff, and additionally run through
`uv run docformatter --in-place` via a `RunOnSave` rule. The Bandit extension reads its config from
`pyproject.toml` (`--configfile pyproject.toml`) — that file lives in `~/.claude`, not this repo.

### Permissions (`.claude/settings.json`)

- **Allowed**: `uv run invoke <clean|dist|lint|path|style|test>*`, `uv run pytest*`
- **Denied**: `git push main*`, `rm:*`, `Read(**/.env)`

### Dependabot

Configured in `.github/dependabot.yml` to check for devcontainer and Docker (`FROM` tags: node, uv)
updates weekly.
