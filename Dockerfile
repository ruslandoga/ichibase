#########
# BUILD #
#########

FROM hexpm/elixir:1.18.3-erlang-27.3.2-alpine-3.21.3 AS build

RUN apk add --no-cache --update git build-base

RUN mkdir /app
WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod
COPY mix.exs mix.lock ./
COPY config/config.exs config/

RUN mix deps.get
RUN mix deps.compile

COPY lib lib
RUN mix compile

COPY config/runtime.exs config/
RUN mix release

#######
# APP #
#######

FROM alpine:3.21.3 AS app

RUN adduser -S -H -u 999 -G nogroup ichi
RUN apk add --no-cache --update openssl libgcc libstdc++ ncurses

COPY --from=build /app/_build/prod/rel/ichi /app
RUN mkdir -p /data && chmod ugo+rw -R /data

USER 999
WORKDIR /app
ENV HOME=/app
VOLUME /data

CMD ["/app/bin/ichi", "start"]
