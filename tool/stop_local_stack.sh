#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHAIN_DIR="$(cd "$ROOT_DIR/../chain-upgrade" && pwd)"
BLOCKSCOUT_DIR="$(cd "$ROOT_DIR/../blockscout/docker-compose" && pwd)"
GRAPH_NODE_DIR="$ROOT_DIR/tool/graph-node"

log() {
  printf '[stop-local-stack] %s\n' "$1"
}

if command -v tmux >/dev/null 2>&1; then
  if tmux has-session -t reef-localnet 2>/dev/null; then
    log "Stopping reef-localnet tmux session"
    tmux kill-session -t reef-localnet
  fi
fi

if [ -d "$GRAPH_NODE_DIR" ] && command -v docker >/dev/null 2>&1; then
  log "Stopping repo-local graph-node stack"
  (
    cd "$GRAPH_NODE_DIR"
    docker compose down -v --remove-orphans >/dev/null 2>&1 || true
  )
fi

if [ -f "$BLOCKSCOUT_DIR/reef-local.yml" ] && command -v docker >/dev/null 2>&1; then
  log "Stopping Reef-local Blockscout stack"
  (
    cd "$BLOCKSCOUT_DIR"
    docker compose -f reef-local.yml down -v --remove-orphans >/dev/null 2>&1 || true
  )
fi

if command -v rm >/dev/null 2>&1; then
  rm -f "$ROOT_DIR/tool/.local_stack_state.json" "$ROOT_DIR/tool/.local_stack_deployment.json"
fi

if command -v pgrep >/dev/null 2>&1; then
  while IFS= read -r pid; do
    if [ -n "$pid" ]; then
      log "Stopping flutter run process $pid"
      kill "$pid" >/dev/null 2>&1 || true
    fi
  done < <(pgrep -f "flutter run.*tool/.local_stack_state.json" || true)
fi

log "Local stack stopped"
