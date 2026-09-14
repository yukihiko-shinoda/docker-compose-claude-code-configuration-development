FROM futureys/claude-code-python-development:20260913152000
ARG VERSION_CSKLINT \
    GCLOUD_VERSION \
	GWS_VERSION \
    BUILDARCH
# csklint: installs and runs the linters for Claude Code skills:
# - skill-validator (pinned inside csklint; 0.1.0 pins 1.5.6, with SHA-256 verification)
# - markdownlint-cli2 (installed via npm, unpinned -- latest at build time)
# `uv tool install` also provisions a uv-managed Python (no system python3 in this image)
# and puts the `csklint` shim in /root/.local/bin, which is already on PATH.
# PyPI: https://pypi.org/project/csklint/
# NOTE: version bump is manual -- Dependabot does not track uv tool installs
RUN uv tool install "csklint==${VERSION_CSKLINT}" \
 && csklint install
COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint
ENTRYPOINT [ "entrypoint" ]
CMD [ "uv", "run", "pytest" ]
# Google Cloud CLI (gcloud)
# - Install gcloud CLI | Google Cloud SDK Documentation
#   https://docs.cloud.google.com/sdk/docs/install#deb
RUN apt-get upgrade -y \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
        apt-transport-https/stable \
        ca-certificates/stable \
        gnupg/stable \
 && apt-get -y autoremove \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends google-cloud-cli=${GCLOUD_VERSION}-0 \
 && apt-get -y autoremove \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
# gws (Google Workspace CLI): single Rust binary from GitHub Releases, no Node.js
# runtime needed.
# - Releases · googleworkspace/cli
#   https://github.com/googleworkspace/cli/releases
RUN case "${BUILDARCH}" in \
        amd64) GWS_TARGET=x86_64-unknown-linux-gnu ;; \
        arm64) GWS_TARGET=aarch64-unknown-linux-gnu ;; \
        *) echo "Unsupported BUILDARCH for gws: ${BUILDARCH}" >&2; exit 1 ;; \
    esac \
 && curl -O -L "https://github.com/googleworkspace/cli/releases/download/v${GWS_VERSION}/google-workspace-cli-${GWS_TARGET}.tar.gz" \
 && curl -O -L "https://github.com/googleworkspace/cli/releases/download/v${GWS_VERSION}/google-workspace-cli-${GWS_TARGET}.tar.gz.sha256" \
 && sha256sum -c "google-workspace-cli-${GWS_TARGET}.tar.gz.sha256" \
 && tar -xzf "google-workspace-cli-${GWS_TARGET}.tar.gz" -C /usr/local/bin ./gws \
 && mv /usr/local/bin/gws /usr/local/bin/gws-real \
 && chmod +x /usr/local/bin/gws-real \
 && rm -f "google-workspace-cli-${GWS_TARGET}.tar.gz" "google-workspace-cli-${GWS_TARGET}.tar.gz.sha256"
# GCP credential source for gws: activates the claude-code service account's
# static JSON key (Docker secret, minted by gcp-agent-key.sh, mounted at
# /opt/claude-agent-secrets/claude-code-key.json -- see compose.yml) with
# gcloud, mints a short-lived GCP OAuth token scoped to Drive/Docs from it,
# then execs into the real gws binary (renamed to gws-real above) with that
# token. Installed AT /usr/local/bin/gws itself (shadowing the real binary),
# not under a separate name like gws-agent, so Claude Code calls the bare
# `gws <service> <resource> <method> --params/--json ...` interface exactly
# as documented by `gws --help`/`gws schema`, with credential injection
# invisible to it. See terraform-google-personal's service_accounts.tf for
# the claude-code service account, and CLAUDE.md for the full chain. gcloud
# stays installed above for this token-minting step even though this wrapper
# no longer uses it for WIF impersonation (see the wrapper's own comments).
# A WIF credential-config JSON for the same fallback path may exist locally
# at ./google-wif-cred-config.json on a given host, but it's gitignored, not
# committed (it names this GCP project's number and the claude-code service
# account's email, which the account owner doesn't want in version control,
# even though the file holds no credential itself) -- regenerate it with
# `gcloud iam workload-identity-pools create-cred-config` (see
# terraform-google-personal/service_accounts.tf's comment above the
# claude_code WIF IAM policy binding) if that fallback path is ever revived.
COPY ./gws-agent.sh /usr/local/bin/gws
RUN chmod +x /usr/local/bin/gws
