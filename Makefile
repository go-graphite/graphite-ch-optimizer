NAME = graphite-ch-optimizer
MODULE = github.com/go-graphite/$(NAME)
VERSION = $(shell git describe --always --tags 2>/dev/null | sed 's:^v::; s/\([^-]*-g\)/c\1/; s|-|.|g')
define DESCRIPTION =
'Service to optimize stale GraphiteMergeTree tables
 This software looking for tables with GraphiteMergeTree engine and evaluate if some of partitions should be optimized. It could work both as one-shot script and background daemon.'
endef
PKG_FILES = $(wildcard out/*$(VERSION)*.deb out/*$(VERSION)*.rpm )
SUM_FILES = out/sha256sum out/md5sum

GO ?= go
GO_VERSION = -ldflags "-X 'main.version=$(VERSION)'"
ifeq ("$(CGO_ENABLED)", "0")
	GOFLAGS += -ldflags=-extldflags=-static
endif
export GO111MODULE := on

SRCS:=$(shell find . -name '*.go')

.PHONY: all clean docker test version

all: $(NAME)
build: $(NAME)
$(NAME): $(SRCS)
	$(GO) build $(GO_VERSION) -o $@ .

version:
	@echo $(VERSION)

clean:
	rm -rf artifact
	rm -rf $(NAME)
	rm -rf out

rebuild: clean all

# Run tests
test:
	$(GO) vet $(MODULE)
	$(GO) test $(MODULE)

static:
	CGO_ENABLED=0 $(MAKE) $(NAME)

docker:
	docker build --label 'org.opencontainers.image.source=https://$(MODULE)' -t ghcr.io/go-graphite/$(NAME):latest .

# we need it static
.PHONY: gox-build
gox-build:
	@CGO_ENABLED=0 $(MAKE) out/$(NAME)-linux-amd64 out/$(NAME)-linux-arm64

out/$(NAME)-linux-%: $(SRCS) | out
	GOOS=linux GOARCH=$* $(GO) build $(GO_VERSION) -o $@ $(MODULE)

out: out/done
out/done:
	mkdir -p out/done

#########################################################
# Prepare artifact directory and set outputs for upload #
#########################################################
github_artifact: $(foreach art,$(PKG_FILES) $(SUM_FILES), artifact/$(notdir $(art)))

artifact:
	mkdir $@

# Link artifact to directory with setting step output to filename
artifact/%: ART=$(notdir $@)
artifact/%: TYPE=$(lastword $(subst ., ,$(ART)))
artifact/%: out/% | artifact
	cp -l $< $@
	@echo '::set-output name=$(TYPE)::$(ART)'

#######
# END #
#######

#############
# Packaging #
#############

# Prepare everything for packaging
out/config.toml.example: $(NAME) | out
	./$(NAME) --print-defaults > $@

nfpm: nfpm-deb nfpm-rpm

PKG_ARCH = amd64 arm64

nfpm-%: out/config.toml.example
	$(MAKE) out/done/$(NAME)-$(VERSION)-amd64-$* ARCH=amd64 PACKAGER=$*
	$(MAKE) out/done/$(NAME)-$(VERSION)-arm64-$* ARCH=arm64 PACKAGER=$*

.ONESHELL:
out/done/$(NAME)-$(VERSION)%: nfpm.yaml | out/done gox-build
	@NAME=$(NAME) DESCRIPTION=$(DESCRIPTION) ARCH=$(ARCH) VERSION_STRING=$(VERSION) nfpm package --packager $(PACKAGER) --target out/
	@touch $@

packages: nfpm $(SUM_FILES)

# md5 and sha256 sum-files for packages
$(SUM_FILES): COMMAND = $(notdir $@)
$(SUM_FILES): PKG_FILES_NAME = $(notdir $(PKG_FILES))
$(SUM_FILES): nfpm
	cd out && $(COMMAND) $(PKG_FILES_NAME) > $(COMMAND)
#######
# END #
#######
