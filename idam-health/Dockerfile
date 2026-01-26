FROM alpine:3.19

RUN apk add --no-cache curl

HEALTHCHECK --interval=10s --timeout=5s --retries=5 --start-period=10s \
  CMD curl -f ${IDAM_URL}/health || exit 1