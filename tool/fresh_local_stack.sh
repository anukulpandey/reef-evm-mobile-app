#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHAIN_DIR="$(cd "$ROOT_DIR/../chain-upgrade" && pwd)"
HARDHAT_DIR="$(cd "$ROOT_DIR/../reef-hardhat-example" && pwd)"
SUBGRAPH_DIR="$(cd "$ROOT_DIR/../v2-subgraph" && pwd)"
BLOCKSCOUT_DIR="$(cd "$ROOT_DIR/../blockscout/docker-compose" && pwd)"
GRAPH_NODE_DIR="$ROOT_DIR/tool/graph-node"
STATE_FILE="$ROOT_DIR/tool/.local_stack_state.json"
DEPLOYMENT_FILE="$ROOT_DIR/tool/.local_stack_deployment.json"
TARGET="${1:-iphone}"
CHAIN_ID="13939"
SUBGRAPH_NAME="uniswap-v2-localhost"
LOCAL_RPC_URL="http://127.0.0.1:8545"
LOCAL_GRAPHQL_URL="http://127.0.0.1:8000/subgraphs/name/$SUBGRAPH_NAME"
LOCAL_VALIDATOR_KEY_JSON="${LOCAL_VALIDATOR_KEY_JSON:-/tmp/validator1.txt}"
DEPLOYER_PREFUND_REEF="${DEPLOYER_PREFUND_REEF:-50000}"

log() {
  printf '[fresh-local-stack] %s\n' "$1"
}

die() {
  printf '[fresh-local-stack] ERROR: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

resolve_host_ip() {
  if [ "$TARGET" != "iphone" ]; then
    printf '127.0.0.1'
    return
  fi

  local interface
  interface="$(route get default 2>/dev/null | awk '/interface:/{print $2; exit}')"
  if [ -n "$interface" ]; then
    local ip
    ip="$(ipconfig getifaddr "$interface" 2>/dev/null || true)"
    if [ -n "$ip" ]; then
      printf '%s' "$ip"
      return
    fi
  fi

  local fallback
  fallback="$(ifconfig 2>/dev/null | awk '/inet / && $2 != "127.0.0.1" {print $2; exit}')"
  [ -n "$fallback" ] || die "Unable to determine a LAN IPv4 address for iPhone launch"
  printf '%s' "$fallback"
}

wait_for_jsonrpc_chain() {
  local url="$1"
  local attempts="${2:-60}"

  for _ in $(seq 1 "$attempts"); do
    local response
    response="$(
      curl -sS \
        -H 'content-type: application/json' \
        -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        "$url" 2>/dev/null || true
    )"
    local chain_hex
    chain_hex="$(printf '%s' "$response" | jq -r '.result // empty' 2>/dev/null || true)"
    if [ -n "$chain_hex" ]; then
      local resolved
      resolved="$((chain_hex))"
      if [ "$resolved" = "$CHAIN_ID" ]; then
        return 0
      fi
    fi
    sleep 2
  done

  return 1
}

wait_for_evm_balance() {
  local url="$1"
  local address="$2"
  local attempts="${3:-60}"

  for _ in $(seq 1 "$attempts"); do
    local response
    response="$(
      curl -sS \
        -H 'content-type: application/json' \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$address\",\"latest\"],\"id\":1}" \
        "$url" 2>/dev/null || true
    )"
    local balance_hex
    balance_hex="$(printf '%s' "$response" | jq -r '.result // empty' 2>/dev/null || true)"
    if [ -n "$balance_hex" ] && [ "$balance_hex" != "0x0" ] && [ "$balance_hex" != "0x" ]; then
      return 0
    fi
    sleep 2
  done

  return 1
}

wait_for_http() {
  local url="$1"
  local attempts="${2:-60}"

  for _ in $(seq 1 "$attempts"); do
    if curl -sS -o /dev/null "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done

  return 1
}

wait_for_subgraph_pair() {
  local url="$1"
  local attempts="${2:-90}"

  for _ in $(seq 1 "$attempts"); do
    local response
    response="$(
      curl -sS \
        -H 'content-type: application/json' \
        -d '{"query":"query FreshPair { pairs(first: 1) { id } }"}' \
        "$url" 2>/dev/null || true
    )"
    local pair_id
    pair_id="$(printf '%s' "$response" | jq -r '.data.pairs[0].id // empty' 2>/dev/null || true)"
    if [ -n "$pair_id" ]; then
      return 0
    fi
    sleep 2
  done

  return 1
}

detect_flutter_device() {
  local machine
  machine="$(flutter devices --machine)"
  case "$TARGET" in
    iphone)
      printf '%s' "$machine" | jq -r \
        '.[] | select((.targetPlatform // "") | startswith("ios")) | .id' | head -n 1
      ;;
    macos)
      printf '%s' "$machine" | jq -r '.[] | select(.id == "macos") | .id' | head -n 1
      ;;
    chrome)
      printf '%s' "$machine" | jq -r '.[] | select(.id == "chrome") | .id' | head -n 1
      ;;
    *)
      die "Unsupported target: $TARGET"
      ;;
  esac
}

resolve_local_private_key() {
  if [ -n "${LOCAL_PRIVATE_KEY:-}" ]; then
    printf '%s' "$LOCAL_PRIVATE_KEY"
    return
  fi

  [ -f "$LOCAL_VALIDATOR_KEY_JSON" ] || die "Missing validator key json at $LOCAL_VALIDATOR_KEY_JSON"
  local secret_seed
  secret_seed="$(jq -r '.secretSeed // empty' "$LOCAL_VALIDATOR_KEY_JSON")"
  [ -n "$secret_seed" ] || die "Missing secretSeed in $LOCAL_VALIDATOR_KEY_JSON"
  printf '%s' "$secret_seed"
}

resolve_local_deployer_address() {
  local private_key="$1"

  (
    cd "$HARDHAT_DIR"
    node -e "const { Wallet } = require('ethers'); console.log(new Wallet(process.argv[1]).address);" "$private_key"
  )
}

prefund_local_deployer() {
  local deployer_address="$1"
  local amount_reef="$2"

  log "Funding fresh deployer $deployer_address with $amount_reef REEF"
  (
    cd "$CHAIN_DIR"
    node --experimental-default-type=module send-to-evm.js --to "$deployer_address" --amount "$amount_reef"
  )
  wait_for_evm_balance "$LOCAL_RPC_URL" "$deployer_address" 60 || die "Fresh deployer $deployer_address did not receive EVM funds"
}

write_subgraph_config() {
  local factory_address="$1"
  local wrapped_address="$2"
  local start_block="$3"
  local config_path="$SUBGRAPH_DIR/config/localhost/config.json"
  local chain_path="$SUBGRAPH_DIR/config/localhost/chain.ts"

  jq \
    --arg factory "$factory_address" \
    --arg startblock "$start_block" \
    '.factory = $factory | .startblock = $startblock' \
    "$config_path" > "$config_path.tmp"
  mv "$config_path.tmp" "$config_path"

  perl -0pi -e "s/export const FACTORY_ADDRESS = '.*?'/export const FACTORY_ADDRESS = '$factory_address'/g" "$chain_path"
  perl -0pi -e "s/export const REFERENCE_TOKEN = '.*?'/export const REFERENCE_TOKEN = '$wrapped_address'/g" "$chain_path"
  perl -0pi -e "s/export const WHITELIST: string\\[\\] = \\[.*?\\]/export const WHITELIST: string[] = ['$wrapped_address']/g" "$chain_path"
}

write_state_file() {
  local host_ip="$1"
  local rpc_url="$2"
  local explorer_base="$3"
  local explorer_api="$4"
  local subgraph_url="$5"

  jq -n \
    --arg REEF_CHAIN_ID "$CHAIN_ID" \
    --arg REEF_RPC_URL "$rpc_url" \
    --arg REEFSWAP_WREEF "$(jq -r '.wrapped' "$DEPLOYMENT_FILE")" \
    --arg REEFSWAP_FACTORY "$(jq -r '.factory' "$DEPLOYMENT_FILE")" \
    --arg REEFSWAP_ROUTER "$(jq -r '.router' "$DEPLOYMENT_FILE")" \
    --arg EXPLORER_BASE_URL "$explorer_base" \
    --arg EXPLORER_API_V2 "$explorer_api" \
    --arg SUBGRAPH_GRAPHQL_ENDPOINT "$subgraph_url" \
    --arg FORCE_RPC_FROM_ENV "true" \
    --arg START_BLOCK "$(jq -r '.startBlock' "$DEPLOYMENT_FILE")" \
    --arg PAIR_ADDRESS "$(jq -r '.pair' "$DEPLOYMENT_FILE")" \
    --arg TOKEN_ADDRESS "$(jq -r '.token' "$DEPLOYMENT_FILE")" \
    --arg DEPLOYER_ADDRESS "$(jq -r '.deployer' "$DEPLOYMENT_FILE")" \
    --arg HOST_IP "$host_ip" \
    '{
      REEF_CHAIN_ID: $REEF_CHAIN_ID,
      REEF_RPC_URL: $REEF_RPC_URL,
      REEFSWAP_WREEF: $REEFSWAP_WREEF,
      REEFSWAP_FACTORY: $REEFSWAP_FACTORY,
      REEFSWAP_ROUTER: $REEFSWAP_ROUTER,
      EXPLORER_BASE_URL: $EXPLORER_BASE_URL,
      EXPLORER_API_V2: $EXPLORER_API_V2,
      SUBGRAPH_GRAPHQL_ENDPOINT: $SUBGRAPH_GRAPHQL_ENDPOINT,
      FORCE_RPC_FROM_ENV: $FORCE_RPC_FROM_ENV,
      START_BLOCK: $START_BLOCK,
      PAIR_ADDRESS: $PAIR_ADDRESS,
      TOKEN_ADDRESS: $TOKEN_ADDRESS,
      DEPLOYER_ADDRESS: $DEPLOYER_ADDRESS,
      HOST_IP: $HOST_IP
    }' > "$STATE_FILE"
}

require_command jq
require_command curl
require_command flutter
require_command docker
require_command tmux
require_command node
require_command npm
require_command yarn
require_command perl

[ -d "$CHAIN_DIR" ] || die "Missing chain repo: $CHAIN_DIR"
[ -d "$HARDHAT_DIR" ] || die "Missing hardhat repo: $HARDHAT_DIR"
[ -d "$SUBGRAPH_DIR" ] || die "Missing subgraph repo: $SUBGRAPH_DIR"
[ -f "$BLOCKSCOUT_DIR/reef-local.yml" ] || die "Missing Reef-local Blockscout compose file"

HOST_IP="$(resolve_host_ip)"
APP_BASE_URL="http://$HOST_IP"
APP_RPC_URL="$APP_BASE_URL:8545"
APP_SUBGRAPH_URL="$APP_BASE_URL:8000/subgraphs/name/$SUBGRAPH_NAME"
APP_EXPLORER_BASE_URL="$APP_BASE_URL"
APP_EXPLORER_API_V2="$APP_BASE_URL/api/v2"

log "Stopping any previous local stack"
"$ROOT_DIR/tool/stop_local_stack.sh"

log "Starting detached Reef local chain"
(cd "$CHAIN_DIR" && make run-local-detached)
wait_for_jsonrpc_chain "$LOCAL_RPC_URL" 90 || die "Local chain RPC did not become ready on $LOCAL_RPC_URL"

LOCAL_DEPLOYER_PRIVATE_KEY="$(resolve_local_private_key)"
LOCAL_DEPLOYER_ADDRESS="$(resolve_local_deployer_address "$LOCAL_DEPLOYER_PRIVATE_KEY")"
prefund_local_deployer "$LOCAL_DEPLOYER_ADDRESS" "$DEPLOYER_PREFUND_REEF"

log "Bootstrapping fresh Reefswap deployment"
rm -f "$DEPLOYMENT_FILE"
(
  cd "$HARDHAT_DIR"
  DEPLOYMENT_JSON_OUT="$DEPLOYMENT_FILE" \
  npm run seed:reefswap:full
)
[ -f "$DEPLOYMENT_FILE" ] || die "Expected deployment JSON at $DEPLOYMENT_FILE"

log "Starting repo-local graph-node stack"
(
  cd "$GRAPH_NODE_DIR"
  docker compose down -v --remove-orphans >/dev/null 2>&1 || true
  docker compose up -d
)
wait_for_http "http://127.0.0.1:5001/api/v0/version" 60 || die "IPFS API did not become ready"
wait_for_http "http://127.0.0.1:8020/" 60 || die "Graph-node admin did not become ready"

log "Rewriting localhost subgraph config from fresh deployment"
write_subgraph_config \
  "$(jq -r '.factory' "$DEPLOYMENT_FILE")" \
  "$(jq -r '.wrapped' "$DEPLOYMENT_FILE")" \
  "$(jq -r '.startBlock' "$DEPLOYMENT_FILE")"

log "Building and deploying localhost subgraph"
(
  cd "$SUBGRAPH_DIR"
  yarn build --network localhost --subgraph-type v2
  npx graph create --node http://127.0.0.1:8020 "$SUBGRAPH_NAME" >/dev/null 2>&1 || true
  npx graph deploy \
    --node http://127.0.0.1:8020 \
    --ipfs http://127.0.0.1:5001 \
    --version-label "local-$(date +%Y%m%d%H%M%S)" \
    "$SUBGRAPH_NAME" \
    v2-subgraph.yaml
)
wait_for_http "$LOCAL_GRAPHQL_URL" 90 || die "Local subgraph GraphQL endpoint did not become ready"
wait_for_subgraph_pair "$LOCAL_GRAPHQL_URL" 90 || die "Local subgraph did not index the seeded pair"

log "Resetting Reef-local Blockscout"
(
  cd "$BLOCKSCOUT_DIR"
  docker compose -f reef-local.yml down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf ./blockscout-db-data ./stats-db-data
  BLOCKSCOUT_PUBLIC_HOST="$HOST_IP" docker compose -f reef-local.yml up -d
)
wait_for_http "http://127.0.0.1/api/v2/main-page/blocks" 120 || die "Blockscout API did not become ready"

log "Writing generated app state"
write_state_file \
  "$HOST_IP" \
  "$APP_RPC_URL" \
  "$APP_EXPLORER_BASE_URL" \
  "$APP_EXPLORER_API_V2" \
  "$APP_SUBGRAPH_URL"

DEVICE_ID="$(detect_flutter_device)"
[ -n "$DEVICE_ID" ] || die "Unable to find a Flutter device for target '$TARGET'"

log "Launching Flutter on $TARGET ($DEVICE_ID)"
cd "$ROOT_DIR"
exec flutter run \
  -d "$DEVICE_ID" \
  --dart-define-from-file="$STATE_FILE"
