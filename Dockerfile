FROM futureys/claude-code-python-development:20260831232000
ARG VERSION_CSKLINT
RUN apt-get update && apt-get install --no-install-recommends -y \
    git/stable \
    # To install GitHub CLI
    wget/stable \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
# GitHub CLI
# - cli/docs/install\_linux.md at trunk · cli/cli
#   https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian
# Reason: To follow the official installation instructions for GitHub CLI, we need to add the GPG key and repository. This is necessary to ensure that we are installing the latest version of GitHub CLI from the official source, rather than relying on potentially outdated versions in the default package repositories.
# hadolint ignore=DL4001
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
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
