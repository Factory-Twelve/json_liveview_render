# CI Plan (single source of truth)

## Trigger policy

- push-branches: main
- push-tags: v*
- pull-request-branches: main

## Commands

- deps: mix deps.get
- format: mix format --check-formatted
- compile: mix compile --warnings-as-errors
- test: MIX_PUBSUB=0 mix test

## Matrix

# version|elixir|otp|checks
1.15|1.15.8|26.2|deps,compile,test
1.19|1.19.5|28.0|deps,format,compile,test
