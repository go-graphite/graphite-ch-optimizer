#
# Image which contains the binary artefacts
#
FROM golang:alpine AS builder

ENV GOPATH=/go

RUN apk add make git --no-cache

WORKDIR /go/src/github.com/go-graphite/graphite-ch-optimizer
COPY . .
RUN make -e CGO_ENABLED=0 build

#
# Application image
#
FROM alpine:latest

RUN apk --no-cache add ca-certificates tzdata && mkdir /graphite-ch-optimizer

WORKDIR /graphite-ch-optimizer

COPY --from=builder \
    /go/src/github.com/go-graphite/graphite-ch-optimizer/graphite-ch-optimizer \
    /go/src/github.com/go-graphite/graphite-ch-optimizer/LICENSE \
  .

ENTRYPOINT ["./graphite-ch-optimizer"]
