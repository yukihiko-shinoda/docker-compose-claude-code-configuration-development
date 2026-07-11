FROM futureys/claude-code-python-development:20260609002000
RUN apt-get update && apt-get install --no-install-recommends -y \
    git/stable \
    # To install GitHub CLI
    wget/stable \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
# GitHub CLI
# - cli/docs/install\_linux.md at trunk · cli/cli
#   https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian
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
