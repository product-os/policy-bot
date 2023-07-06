# FIXME: https://github.com/palantir/policy-bot/issues/558
FROM alpine:latest AS build

RUN apk add --no-cache github-cli

# https://github.com/palantir/policy-bot/actions/runs/4997327086
# https://github.com/palantir/policy-bot/suites/12944825591/artifacts/699636686
ARG GH_RUN_ID=4997327086

RUN --mount=type=secret,id=GITHUB_TOKEN \
    GH_TOKEN=$(cat < /run/secrets/GITHUB_TOKEN) gh run download -R palantir/policy-bot ${GH_RUN_ID} \
    && find dist -type f -name '*.tgz' | xargs tar -zxvf \
    && ln -s $(find . -name 'policy-bot-*' -maxdepth 1) build \
    && readlink -n build | awk -F'/' '{print $2}' > build/.version


# https://hub.docker.com/r/palantirtechnologies/policy-bot
# https://github.com/palantir/policy-bot/blob/develop/docker/Dockerfile
FROM alpine

STOPSIGNAL SIGINT

ARG TARGERTARCH=arm64
ENV TARGERTARCH ${TARGERTARCH}

WORKDIR /policy-bot

COPY --from=build build/ .

RUN ln -s $(pwd)/bin/linux-${TARGERTARCH}/policy-bot $(pwd)/bin/policy-bot

# add the default configuration file
COPY src/config/policy-bot.example.yml /secrets/policy-bot.yml

COPY src/docker/ca-certificates.crt /etc/ssl/certs/
COPY src/docker/mime.types /etc/

ENTRYPOINT ["bin/policy-bot"]
CMD ["server", "--config", "/secrets/policy-bot.yml"]
