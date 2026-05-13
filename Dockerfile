# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.3
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libvips42 \
      libpq5 \
      libjemalloc2 \
      poppler-utils \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_LOG_TO_STDOUT="1" \
    RAILS_SERVE_STATIC_FILES="1" \
    RUBY_YJIT_ENABLE="1" \
    PORT="3000"

# Use jemalloc — resolve path dynamically to support both amd64 and arm64
RUN JEMALLOC=$(find /usr -name "libjemalloc.so.2" 2>/dev/null | head -1) && \
    echo "LD_PRELOAD=${JEMALLOC}" >> /etc/environment && \
    echo "export LD_PRELOAD=${JEMALLOC}" >> /etc/profile.d/jemalloc.sh

# Build stage
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libvips-dev \
      libpq-dev \
      libjemalloc-dev \
      libyaml-dev \
      pkg-config \
      poppler-utils \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    bundle exec bootsnap precompile --gemfile

COPY . .

RUN bundle exec bootsnap precompile app/ lib/ && \
    SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

# Runtime stage
FROM base AS runtime

RUN groupadd --system --gid 1000 rails && \
    useradd  --system --uid 1000 --gid rails --home /rails rails

COPY --from=build --chown=rails:rails /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=rails:rails /rails /rails

USER rails

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s \
  CMD curl -fs http://localhost:${PORT}/up || exit 1

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
