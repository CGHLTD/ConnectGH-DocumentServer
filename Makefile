COMPANY_NAME ?= ONLYOFFICE
GIT_BRANCH ?= develop
PRODUCT_NAME ?= documentserver
PRODUCT_EDITION ?= 
PRODUCT_VERSION ?= 9.4.0
BUILD_NUMBER ?= 0
BUILD_CHANNEL ?= nightly
ONLYOFFICE_VALUE ?= onlyoffice

COMPANY_NAME_LOW = $(shell echo $(COMPANY_NAME) | tr A-Z a-z)

PACKAGE_NAME := $(COMPANY_NAME_LOW)-$(PRODUCT_NAME)$(PRODUCT_EDITION)
PACKAGE_VERSION ?= $(PRODUCT_VERSION)
# Empty lets the Dockerfile pick the upstream ONLYOFFICE package repo.
PACKAGE_BASEURL ?=

ifeq ($(BUILD_CHANNEL),$(filter $(BUILD_CHANNEL),nightly test))
	DOCKER_TAG := $(PRODUCT_VERSION).$(BUILD_NUMBER)
else
	DOCKER_TAG := $(PRODUCT_VERSION).$(BUILD_NUMBER)-$(subst /,-,$(GIT_BRANCH))
endif

DOCKER_ORG ?= connectgh
DOCKER_IMAGE := $(DOCKER_ORG)/$(PRODUCT_NAME)$(PRODUCT_EDITION)
DOCKER_TARGET := documentserver-$(if $(PRODUCT_EDITION),enterprise,community)
DOCKER_DUMMY := $(DOCKER_ORG)-$(PRODUCT_NAME)$(PRODUCT_EDITION)__$(DOCKER_TAG).dummy
DOCKER_ARCH := $(DOCKER_ORG)-$(PRODUCT_NAME)$(PRODUCT_EDITION)_$(DOCKER_TAG).tar.gz

.PHONY: all clean clean-docker image deploy docker

$(DOCKER_DUMMY):
	docker pull ubuntu:24.04
	docker build \
		--target $(DOCKER_TARGET) \
		--build-arg COMPANY_NAME=$(COMPANY_NAME_LOW) \
		--build-arg PRODUCT_NAME=$(PRODUCT_NAME) \
		--build-arg PRODUCT_EDITION=$(PRODUCT_EDITION) \
		--build-arg PACKAGE_VERSION=$(PACKAGE_VERSION) \
		--build-arg PACKAGE_BASEURL=$(PACKAGE_BASEURL) \
		--build-arg ONLYOFFICE_VALUE=$(ONLYOFFICE_VALUE) \
		-t $(DOCKER_IMAGE):$(DOCKER_TAG) . && \
	mkdir -p $$(dirname $@) && \
	echo "Done" > $@

$(DOCKER_ARCH): $(DOCKER_DUMMY)
	docker save $(DOCKER_IMAGE):$(DOCKER_TAG) | \
		gzip > $@

all: image

clean:
	rm -rfv *.dummy *.tar.gz
		
clean-docker:
	docker rmi -f $$(docker images -q '$(DOCKER_ORG)/*') || exit 0

image: $(DOCKER_DUMMY)

deploy: $(DOCKER_DUMMY)
	for i in {1..3}; do \
		docker push $(DOCKER_IMAGE):$(DOCKER_TAG) && break || sleep 1m; \
	done
ifeq ($(BUILD_CHANNEL),nightly)
	docker tag $(DOCKER_IMAGE):$(DOCKER_TAG) $(DOCKER_IMAGE):latest
	for i in {1..3}; do \
		docker push $(DOCKER_IMAGE):latest && break || sleep 1m; \
	done
endif
