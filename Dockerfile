ARG DOCKER_IMAGE_TAG_NODE=26.5.0-trixie-slim \
    VERSION_UV=0.11.28
FROM ghcr.io/astral-sh/uv:${VERSION_UV} AS uv
FROM node:${DOCKER_IMAGE_TAG_NODE}
ARG VERSION_CLAUDE_CODE=stable
ARG VERSION_CSKLINT
WORKDIR /workspace
COPY --from=uv /uv /uvx /bin/
# - Using uv in Docker | uv
#   https://docs.astral.sh/uv/guides/integration/docker/#caching
ENV UV_LINK_MODE=copy
RUN apt-get update && apt-get install --no-install-recommends -y \
    #   For `ps` command, otherwise following error occurs when running claude-code::
    # - [BUG] Node.js error when `ps` is unavailable · Issue #2276 · anthropics/claude-code
    #   https://github.com/anthropics/claude-code/issues/2276
    procps/stable \
    #   For running Semgrep, otherwise following error occurs:
    #   Fatal error: exception Failure: ca-certs: no trust anchor file found, looked into
    #     /etc/ssl/certs/ca-certificates.crt,
    #     /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem,
    #     /etc/ssl/ca-bundle.pem.
    ca-certificates/stable \
    # To install Claude Code
    curl/stable \
    git/stable \
    # To install GitHub CLI
    wget/stable \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
# Claude Code
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# - Troubleshoot installation and login - Claude Code Docs
#   https://code.claude.com/docs/en/troubleshoot-install#verify-your-path
# This setting should be set before running the installation script, otherwise installation may fail with the following error:
#   56.76 ⚠ Setup notes:
#   56.76   ● Native installation exists but ~/.local/bin is not in your PATH. Run:
#   56.76
#   56.76     echo 'export PATH="$HOME/.local/bin:$PATH"' >> your shell config file && source your shell config file
#   58.77
#   58.77 ✔ Claude Code successfully installed!
#   58.77
#   58.77   Version: 2.1.197
#   58.77
#   58.77   Location: ~/.local/bin/claude
#   58.77
#   58.77
#   58.77   Next: Run claude --help to get started
#   58.77
#   58.77 ⚠ Setup notes:
#   58.77   ● Native installation exists but ~/.local/bin is not in your PATH. Run:
#   58.77
#   58.77     echo 'export PATH="$HOME/.local/bin:$PATH"' >> your shell config file && source your shell config file
#   60.79
#   60.82
#   60.82 ✅ Installation complete!
ENV PATH="/root/.local/bin:${PATH}"
RUN curl -fsSL https://claude.ai/install.sh | bash -s "${VERSION_CLAUDE_CODE}"
ENV DISABLE_AUTOUPDATER=1
# GitHub CLI
# - cli/docs/install\_linux.md at trunk · cli/cli
#   https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian
# Reason: To follow the official installation instructions for GitHub CLI, we need to add the GPG key and repository. This is necessary to ensure that we are installing the latest version of GitHub CLI from the official source, rather than relying on potentially outdated versions in the default package repositories.
# hadolint ignore=DL4001
RUN mkdir -p /etc/apt/keyrings \
 && chmod -R 0755 /etc/apt/keyrings \
 && out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
 && cat "$out" | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
 && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && mkdir -p /etc/apt/sources.list.d \
 && chmod -R 0755 /etc/apt/sources.list.d \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
 && apt-get update && apt-get install --no-install-recommends -y \
    gh/stable \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
# csklint: installs and runs the linters for Claude Code skills:
# - skill-validator (pinned inside csklint; 0.1.0 pins 1.5.6, with SHA-256 verification)
# - markdownlint-cli2 (installed via npm, unpinned -- latest at build time)
# `uv tool install` also provisions a uv-managed Python (no system python3 in this image)
# and puts the `csklint` shim in /root/.local/bin, which is already on PATH.
# PyPI: https://pypi.org/project/csklint/
# NOTE: version bump is manual -- Dependabot does not track uv tool installs
RUN uv tool install "csklint==${VERSION_CSKLINT}" \
 && csklint install
ENTRYPOINT [ "uv", "run" ]
CMD ["pytest"]
