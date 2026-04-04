set dotenv-load

default:
  just --list --list-submodules

sync:
  uv sync --all-groups

test:
  uv run pytest tests/ -v

lint:
  uv run ruff check src tests

fmt:
  uv run ruff format src tests

build:
  uv build

mock:
  nix run nixpkgs#websocat -- -vv ws-l:0.0.0.0:8092 mirror:
