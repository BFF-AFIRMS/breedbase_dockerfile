FROM ankane/pghero:v4.0.1

RUN apk update \
  && apk add curl

# Create custom controlled user
RUN addgroup -S pghero && adduser -S pghero -G pghero
USER pghero
