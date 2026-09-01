FROM caddy:2.11.4

RUN apk update \
  && apk add curl nss-tools

RUN addgroup -S caddy && adduser -S caddy -G caddy

RUN mkdir -p /srv/www && chown -R caddy:caddy /srv/www

USER caddy
