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

Built `FROM futureys/claude-code-python-development:<tag>`, a maintained base image (already carrying
Node, `uv`/`uvx`, git, GitHub CLI, and the native Claude Code install) whose tag is bumped by
Dependabot's `docker` ecosystem check. On top of that base, the Dockerfile only adds the skill
linters: `csklint` (<https://pypi.org/project/csklint/>) is installed as a pinned
`uv tool install "csklint==${VERSION_CSKLINT}"` followed by `csklint install`, which provisions
`skill-validator` (pinned internally, with checksum verification) and `markdownlint-cli2` (installed
via npm, unpinned — latest at build time). The csklint version bump is manual — not tracked by
Dependabot. `csklint run` is also available at runtime to lint the skills under `~/.claude/skills`.
`compose.yml` passes `VERSION_CSKLINT` as a plain build arg (currently `0.3.0`) rather than requiring
it from a shell-sourced `.env` file, so — unlike the version-pinning scheme this repo used
previously — a compose build needs no `.env` for the image tag or `csklint` version.

`entrypoint.sh` is copied into the image as `/usr/local/bin/entrypoint` and set as `ENTRYPOINT`
(`CMD` is `uv run pytest`). It runs `uvx hol-guard install claude-code` before `exec`-ing the
container's command, so every container start (re-)installs HOL Guard's Claude Code integration
before anything else runs.

`compose.yml` grants `cap_add: SYS_ADMIN` and `security_opt: seccomp:unconfined` so that Claude
Code's own Bash sandbox (which uses bubblewrap) can create the namespaces it needs from inside this
already-containerized environment — see the comment above those keys in `compose.yml`, and
[containers/bubblewrap#505](https://github.com/containers/bubblewrap/issues/505) for cases where even
a long capability list still falls short of `--privileged`. It also declares a Docker secret,
`slack_webhook_url`, sourced from the host's `SLACK_WEBHOOK_URL` environment variable (Compose's
`secrets: <name>: environment:` form) — this keeps the Slack webhook used by `~/.claude`'s
notification hook out of the read-write `~/.claude` bind mount. Key volume mounts:

| Mount | Purpose |
| --- | --- |
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

### Permissions and sandbox (`.claude/settings.json`)

- **Allowed**: `uv run invoke <clean|dist|lint|path|style|test>*`, `uv run pytest*`
- **`sandbox`**: `{"enabled": true, "enableWeakerNestedSandbox": true}` — Claude Code's built-in Bash
  sandbox is turned on inside the container, paired with the `cap_add`/`security_opt` grants in
  `compose.yml` above that make bubblewrap usable there. There is no `permissions.deny` list — the
  sandbox is now the guardrail in place of the deny rules this repo used previously.

### Dependabot

Configured in `.github/dependabot.yml` to check the `devcontainers`, `docker` (the Dockerfile's
`FROM` tag), `docker-compose`, `github-actions`, and `uv` ecosystems weekly, all rooted at `/`.
