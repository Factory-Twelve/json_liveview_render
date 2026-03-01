SHELL := /bin/bash

.PHONY: help ci-local ci-local-full release-check

help:
	@echo "Available targets:"
	@echo "  ci-local        Run local CI checks for 1.15 matrix slot"
	@echo "  ci-local-full   Run local CI checks for 1.15 and 1.19"
	@echo "  release-check   Run release sanity checks + hex dry-run publish"

release-check:
	mix json_liveview_render.check_metadata
	mix format --check-formatted
	mix compile --warnings-as-errors
	MIX_PUBSUB=0 mix test
	mix hex.publish --dry-run

ci-local:
	./scripts/ci_local.sh --matrix 1.15

ci-local-full:
	./scripts/ci_local.sh --matrix 1.15,1.19
