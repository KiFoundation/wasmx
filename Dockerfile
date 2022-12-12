# To build the wasmx image, just run:
# > docker build -t wasmx .
#
# In order to work properly, this Docker container needs to have a volume that:
# - as source points to a directory which contains a config.toml and firebase-config.toml files
# - as destination it points to the /home folder
#
# Simple usage with a mounted data directory (considering ~/.wasmx/config as the configuration folder):
# > docker run -it -v ~/.wasmx/config:/home wasmx wasmx parse config.toml firebase-config.json
#
# If you want to run this container as a daemon, you can do so by executing
# > docker run -td -v ~/.wasmx/config:/home --name wasmx wasmx
#
# Once you have done so, you can enter the container shell by executing
# > docker exec -it wasmx bash
#
# To exit the bash, just execute
# > exit
FROM --platform=linux/amd64 golang:alpine AS build-env

# Install dependencies
RUN apk update && \
    apk add --no-cache curl make git libc-dev bash gcc linux-headers eudev-dev py-pip ca-certificates build-base python3

# Set working directory for the build
WORKDIR /wasmx

# Add source files
COPY . .

# See https://github.com/CosmWasm/wasmvm/releases
ADD https://github.com/CosmWasm/wasmvm/releases/download/v1.0.0/libwasmvm_muslc.x86_64.a /lib/libwasmvm_muslc.a
RUN sha256sum /lib/libwasmvm_muslc.a | grep f6282df732a13dec836cda1f399dd874b1e3163504dbd9607c6af915b2740479

# Build binary
RUN BUILD_TAGS=muslc LINK_STATICALLY=true make install

# Final image
FROM --platform=linux/amd64 alpine:edge

# Install ca-certificates
RUN apk add --update ca-certificates
WORKDIR /home

# Install bash
RUN apk add --no-cache bash

# Copy over binaries from the build-env
COPY --from=build-env /go/bin/wasmx /usr/bin/wasmx
