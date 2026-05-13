# syntax=docker/dockerfile:1
# ──────────────────────────────────────────────────────────────
# Stage 1: build gems + compile assets
# ──────────────────────────────────────────────────────────────
FROM ruby:3.3-slim AS build

# Build-time deps only — not carried into the runtime image
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      git \
      curl \
      libvips-dev \
      libpq-dev \
      libjemalloc-dev \
      pkg-config \
      poppler-utils \
    && rm -rf /var/lib/apt/lists/*

ENV BUNDLE_WITHOUT="development:test" \
    BUNDLE_DEPLOYMENT="1" \
    RAILS_ENV="production"

WORKDIR /app

# Install gems first (cache layer)
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    bundle exec bootsnap precompile --gemfile

# Copy app source
COPY . .

# Precompile bootsnap and assets
RUN bundle exec bootsnap precompile app/ lib/ && \
    SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

# ──────────────────────────────────────────────────────────────
# Stage 2: lean runtime image
# ──────────────────────────────────────────────────────────────
FROM ruby:3.3-slim AS runtime

# Runtime deps only — no compilers, no -dev headers
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      libvips42 \
      libpq5 \
      libjemalloc2 \
      poppler-utils \
      curl \
    && rm -rf /var/lib/apt/lists/*

# Use jemalloc to curb memory bloat on free-tier hosts (Render, Fly.io)
# The shared lib path differs by arch; resolve at build time.
RUN JEMALLOC_PATH=$(find /usr -name "libjemalloc.so.2" 2>/dev/null | head -1) && \
    echo "export LD_PRELOAD=${JEMALLOC_PATH}" >> /etc/environment
ENV LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libjemalloc.so.2

# Tune jemalloc for low-RAM environments
ENV MALLOC_CONF="narenas:2,background_thread:true,dirty_decay_ms:1000,muzzy_decay_ms:1000"

# Enable YJIT (Ruby 3.3+ on by default, but be explicit)
ENV RUBY_YJIT_ENABLE=1

ENV RAILS_ENV="production" \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_DEPLOYMENT="1" \
    RAILS_LOG_TO_STDOUT="1" \
    RAILS_SERVE_STATIC_FILES="1" \
    PORT="3000"

WORKDIR /app

# Non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd  --system --uid 1000 --gid rails --home /app rails

# Copy built artefacts from the build stage
COPY --from=build --chown=rails:rails /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=rails:rails /app /app

USER rails

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD curl -fs http://localhost:3000/up || exit 1

# Thruster wraps Puma with HTTP/2, TLS termination, and asset compression
CMD ["bundle", "exec", "thrust", "bundle", "exec", "puma", "-C", "config/puma.rb"]
