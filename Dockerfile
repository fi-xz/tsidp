# Build tsidp
FROM golang:1.24-alpine AS build-env

WORKDIR /go/src/tailscale

COPY ./tailscale/go.mod ./tailscale/go.sum ./
RUN go mod download

# Pre-build some stuff before the following COPY line invalidates the Docker cache.
RUN go install \
    github.com/aws/aws-sdk-go-v2/aws \
    github.com/aws/aws-sdk-go-v2/config \
    gvisor.dev/gvisor/pkg/tcpip/adapters/gonet \
    gvisor.dev/gvisor/pkg/tcpip/stack \
    golang.org/x/crypto/ssh \
    golang.org/x/crypto/acme \
    github.com/coder/websocket \
    github.com/mdlayher/netlink

COPY ./tailscale .
RUN GOOS=linux GOARCH=arm64 go build -o tsidp ./cmd/tsidp

# Run tsidp
FROM arm64v8/alpine:3.18
RUN apk add --no-cache ca-certificates iptables iproute2 ip6tables

COPY --from=build-env /go/src/tailscale/tsidp /usr/local/bin/

ARG TS_HOSTNAME="tsidp"
ENV TS_HOSTNAME=$TS_HOSTNAME
ARG TS_AUTHKEY=""
ENV TS_AUTHKEY=$TS_AUTHKEY
ARG TS_USERSPACE=false
ENV TS_USERSPACE=$TS_USERSPACE
ARG VERBOSE=false
ENV VERBOSE=$VERBOSE
ARG TAILSCALE_USE_WIP_CODE=1
ENV TAILSCALE_USE_WIP_CODE=$TAILSCALE_USE_WIP_CODE

CMD tsidp -verbose=$VERBOSE
