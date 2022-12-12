VERSION := $(shell echo $(shell git describe --tags) | sed 's/^v//')
COMMIT  := $(shell git log -1 --format='%H')
DOCKER := $(shell which docker)

export GO111MODULE = on


ldflags = -X github.com/forbole/juno/v3/cmd.Version=$(VERSION) \
	-X github.com/forbole/juno/v3/cmd.Commit=$(COMMIT)

build_tags += $(BUILD_TAGS)
build_tags := $(strip $(build_tags))

ifeq ($(LINK_STATICALLY),true)
  ldflags += -linkmode=external -extldflags "-Wl,-z,muldefs -static"
endif

ldflags += $(LDFLAGS)
ldflags := $(strip $(ldflags))

BUILD_FLAGS := -tags "$(build_tags)" -ldflags '$(ldflags)'
# check for nostrip option
ifeq (,$(findstring nostrip,$(KID_BUILD_OPTIONS)))
  BUILD_FLAGS += -trimpath
endif



all: ci-lint ci-test install

###############################################################################
# Build / Install
###############################################################################

build: go.sum
ifeq ($(OS),Windows_NT)
	@echo "building wasmx binary..."
	@go build -mod=readonly $(BUILD_FLAGS) -o build/wasmx.exe ./cmd/wasmx
else
	@echo "building wasmx binary..."
	@go build -mod=readonly $(BUILD_FLAGS) -o build/wasmx ./cmd/wasmx
endif

install: go.sum
	@echo "installing wasmx binary..."
	@go install -mod=readonly $(BUILD_FLAGS) ./cmd/wasmx

build-reproducible: go.sum
	$(DOCKER) rm $(subst /,-,latest-build-wasmx) || true
	DOCKER_BUILDKIT=1 $(DOCKER) build -t latest-build-wasmx \
		--build-arg COMMIT="$(COMMIT)" \
		--build-arg VERSION="$(VERSION)" \
		-f Dockerfile .
	$(DOCKER) create -ti --name $(subst /,-,latest-build-wasmx) latest-build-wasmx wasmx
	mkdir -p $(CURDIR)/build/
	$(DOCKER) cp -a $(subst /,-,latest-build-wasmx):/usr/bin/wasmx $(CURDIR)/build/wasmx



###############################################################################
# Tests / CI
###############################################################################

lint:
	golangci-lint run --out-format=tab

lint-fix:
	golangci-lint run --fix --out-format=tab --issues-exit-code=0
.PHONY: lint lint-fix

format:
	find . -name '*.go' -type f -not -path "*.git*" | xargs gofmt -w -s
	find . -name '*.go' -type f -not -path "*.git*" | xargs misspell -w
	find . -name '*.go' -type f -not -path "*.git*" | xargs goimports -w -local github.com/disperze/wasmx
.PHONY: format

clean:
	rm -f tools-stamp ./build/**

.PHONY: install build ci-test ci-lint clean
