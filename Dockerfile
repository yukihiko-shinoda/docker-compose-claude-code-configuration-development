FROM futureys/claude-code-python-development:20260906204000
ARG VERSION_CSKLINT
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
