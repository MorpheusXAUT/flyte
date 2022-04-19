export REPOSITORY=flyte
include boilerplate/flyte/end2end/Makefile

define PIP_COMPILE
pip-compile $(1) --upgrade --verbose
endef

GIT_VERSION := $(shell git describe --always --tags)
GIT_HASH := $(shell git rev-parse --short HEAD)
TIMESTAMP := $(shell date '+%Y-%m-%d')
PACKAGE ?=github.com/flyteorg/flytestdlib
LD_FLAGS="-s -w -X $(PACKAGE)/version.Version=$(GIT_VERSION) -X $(PACKAGE)/version.Build=$(GIT_HASH) -X $(PACKAGE)/version.BuildTime=$(TIMESTAMP)"

.PHONY: compile
compile:
	go build -o flyte -ldflags=$(LD_FLAGS) ./cmd/ && mv ./flyte ${GOPATH}/bin

.PHONY: linux_compile
linux_compile:
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0  go build -o /artifacts/flyte -ldflags=$(LD_FLAGS) ./cmd/

.PHONY: update_boilerplate
update_boilerplate:
	@boilerplate/update.sh

.PHONY: kustomize
kustomize:
	KUSTOMIZE_VERSION=3.9.2 bash script/generate_kustomize.sh

.PHONY: helm
helm: ## Generate K8s Manifest from Helm Charts.
	bash script/generate_helm.sh

.PHONY: release_automation
release_automation:
	mkdir -p release
	bash script/release.sh
	bash script/generate_config_docs.sh

.PHONY: deploy_sandbox
deploy_sandbox: 
	bash script/deploy.sh

.PHONY: install-piptools
install-piptools: ## Install pip-tools
	pip install -U pip-tools

.PHONY: doc-requirements.txt
doc-requirements.txt: doc-requirements.in install-piptools
	$(call PIP_COMPILE,doc-requirements.in)

.PHONY: requirements.txt
requirements.txt: requirements.in install-piptools
	$(call PIP_COMPILE,requirements.in)

.PHONY: stats
stats:
	@generate-dashboard -o deployment/stats/prometheus/flytepropeller-dashboard.json stats/flytepropeller_dashboard.py
	@generate-dashboard -o deployment/stats/prometheus/flyteadmin-dashboard.json stats/flyteadmin_dashboard.py
	@generate-dashboard -o deployment/stats/prometheus/flyteuser-dashboard.json stats/flyteuser_dashboard.py

.PHONY: prepare_artifacts
prepare_artifacts:
	bash script/prepare_artifacts.sh

.PHONE: helm_update
helm_update: ## Update helm charts' dependencies.
	helm dep update ./charts/flyte/

.PHONY: helm_install
helm_install: ## Install helm charts
	helm install flyte --debug ./charts/flyte -f ./charts/flyte/values.yaml --create-namespace --namespace=flyte

.PHONY: helm_upgrade
helm_upgrade: ## Upgrade helm charts
	helm upgrade flyte --debug ./charts/flyte -f ./charts/flyte/values.yaml --create-namespace --namespace=flyte

.PHONY: docs
docs:
	make -C rsts clean html SPHINXOPTS=-W

.PHONY: help
help: SHELL := /bin/sh
help: ## List available commands and their usage
	@awk 'BEGIN {FS = ":.*?##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } ' $(MAKEFILE_LIST)

.PHONY: setup_local_dev
setup_local_dev: ## Sets up k3d cluster with Flyte dependencies for local development
	bash script/setup_local_dev.sh