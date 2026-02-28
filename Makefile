SHELL := /bin/bash

.PHONY: ci-local ci-local-full
ci-local:
	./scripts/ci_local.sh --matrix 1.15

ci-local-full:
	./scripts/ci_local.sh --matrix 1.15,1.19
