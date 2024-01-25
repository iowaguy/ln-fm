# FROM ubuntu:jammy
FROM golang:1.19.7-alpine as builder

# Force Go to use the cgo based DNS resolver. This is required to ensure DNS
# queries required to connect to linked containers succeed.
ENV GODEBUG netdns=cgo

# Install dependencies.
RUN apk add --no-cache --update alpine-sdk \
    git \
    make

# Copy in the local repository to build from.
COPY . /go/src/proxyclient/

#  Install/build lnd.
RUN cd /go/src/proxyclient/ \
    && go mod tidy \
    && go build -v \
    && go install -v

# Start a new, final image to reduce size.
FROM alpine as final

# Copy the binaries and entrypoint from the builder image.
COPY --from=builder /go/bin/proxyclient /bin/

# Add bash.
RUN apk add --no-cache \
    bash

# Copy the entrypoint script.
# COPY "docker/lnd/start-lnd.sh" .
# RUN chmod +x start-lnd.sh
# FROM ubuntu:jammy

# # Install build dependencies such as git and glide.
# RUN apt-get update -y && \
#     apt-get install -y build-essential \
#     python-dev-is-python3 \
#     python3-dev \
#     libgmp3-dev \
#     python3-pip \
#     bash \
#     ca-certificates && \
#     pip3 install bitcoinlib

# WORKDIR /app/

# # COPY "proxyclient.py" .

# # RUN chmod +x proxyclient.py

# # Expose mainnet ports (server, rpc)
# EXPOSE 8080 8080
