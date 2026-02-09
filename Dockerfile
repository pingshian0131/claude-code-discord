# Claude Code Discord Bot
# Multi-stage build for optimized production image

FROM denoland/deno:latest

# Set working directory
WORKDIR /app

# Set environment variable to indicate Docker container
ENV DOCKER_CONTAINER=true

# Install git, Node.js, Claude Code CLI, Python 3.11, and system dependencies
USER root
RUN apt-get update && apt-get install -y \
    git curl \
    python3 python3-dev python3-venv python3-pip \
    default-libmysqlclient-dev pkg-config build-essential \
    libgl1 libglib2.0-0 \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g @anthropic-ai/claude-code \
    && pip install --break-system-packages pipenv \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user with uid 1000 to match host file permissions
RUN groupadd -g 1000 claude && useradd -u 1000 -g claude -m claude

# Copy all source files first (as root)
COPY . .

# Remove lockfile if present (avoid version conflicts)
RUN rm -f deno.lock

# Initialize git repo in container (for non-git workspaces)
RUN git init && git config user.email "bot@claude.local" && git config user.name "Claude Bot"

# Pre-compile dependencies as root (before switching user)
RUN deno cache --no-lock index.ts

# Create data directory for persistence and set ownership
RUN mkdir -p .bot-data && chown -R claude:claude /app

# Switch to non-root user
USER claude

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD deno eval "console.log('healthy')" || exit 1

# Default command
CMD ["deno", "run", "--allow-all", "--no-lock", "index.ts"]

# Labels for image metadata
LABEL org.opencontainers.image.source="https://github.com/zebbern/claude-code-discord"
LABEL org.opencontainers.image.description="Claude Code Discord Bot - Use Claude AI via Discord"
LABEL org.opencontainers.image.licenses="MIT"
