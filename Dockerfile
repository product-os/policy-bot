# FIXME: https://github.com/palantir/policy-bot/issues/558

# https://github.com/palantir/policy-bot/blob/develop/.palantir/go-version
FROM golang:1.23.4-alpine3.19 AS build

WORKDIR /src

# hadolint ignore=DL3018
RUN apk add --no-cache bash git nodejs npm yarn curl wget

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ENV CGO_ENABLED=0

# renovate: datasource=github-releases depName=palantir/policy-bot
ARG POLICY_BOT_VERSION=v1.36.5

RUN git clone --depth 1 -c advice.detachedHead=false \
	--branch "$POLICY_BOT_VERSION" https://github.com/palantir/policy-bot.git .

# https://github.com/palantir/policy-bot/blob/develop/.github/workflows/build.yml

# Install frontend dependencies
# hadolint ignore=DL3059
RUN yarn install

# Build frontend
# hadolint ignore=DL3059
RUN yarn run build:production

# Build distribution
# hadolint ignore=DL3059
RUN ./godelw dist

# https://hub.docker.com/r/palantirtechnologies/policy-bot
# https://github.com/palantir/policy-bot/blob/develop/docker/Dockerfile
FROM alpine:3.23

WORKDIR /policy-bot

COPY --from=build /src/build/policy-bot/*/bin/policy-bot-*.tgz ./policy-bot.tgz
# add the default configuration file
COPY --from=build /src/config/policy-bot.example.yml /secrets/policy-bot.yml

ARG TARGETARCH

RUN tar -zxvf policy-bot.tgz --strip-components=1 && \
	ln -s "$(pwd)/bin/linux-${TARGETARCH}/policy-bot" "$(pwd)/bin/policy-bot" && \
	rm policy-bot.tgz

COPY src/docker/ca-certificates.crt /etc/ssl/certs/
COPY src/docker/mime.types /etc/

RUN bin/policy-bot --help

ENTRYPOINT [ "bin/policy-bot" ]
CMD [ "server", "--config", "/secrets/policy-bot.yml" ]
STOPSIGNAL SIGINT
