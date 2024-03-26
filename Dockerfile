FROM alpine:3.19

RUN apk update && apk upgrade && apk add --no-cache git jq curl

WORKDIR /usr/src

COPY entrypoint.sh .

ENTRYPOINT ["/usr/src/entrypoint.sh"]
