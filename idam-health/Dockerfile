FROM alpine:3.19

RUN apk add --no-cache curl \
  && addgroup -S hmcts \
  && adduser -S -G hmcts hmcts

USER hmcts

CMD [ "tail", "-f", "/dev/null" ]
