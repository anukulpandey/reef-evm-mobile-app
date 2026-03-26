# Codex Runbook (reef-evm-mobile-app)

This file captures the exact local-stack workflow for this repo so future requests can be short:

- "follow `CODEX_RUNBOOK.md` startup"
- "follow `CODEX_RUNBOOK.md` shutdown"

## Startup
From `/Users/anukul/Desktop/reef-evm-mobile-app`:

```bash
./tool/fresh_local_stack.sh
```

Targets:

```bash
./tool/fresh_local_stack.sh iphone
./tool/fresh_local_stack.sh macos
./tool/fresh_local_stack.sh chrome
```

What it does:

- stops any previous local chain / graph-node / Blockscout stack
- starts the detached local Reef chain
- bootstraps fresh Reefswap contracts and seeded activity
- rewrites localhost subgraph config and redeploys `uniswap-v2-localhost`
- prunes and restarts Reef-local Blockscout
- generates `tool/.local_stack_state.json`
- launches Flutter with `--dart-define-from-file=tool/.local_stack_state.json`

## Generated State
- Runtime config source of truth: `tool/.local_stack_state.json`
- Raw deployment output captured from contract bootstrap: `tool/.local_stack_deployment.json`

These files are local-only and regenerated every run.

## Shutdown

```bash
./tool/stop_local_stack.sh
```

What it stops:

- `reef-localnet` tmux session in `../chain-upgrade`
- repo-local Docker graph-node stack
- Reef-local Blockscout Docker stack
- any local `flutter run` process launched with the generated state file

## Notes
- Default target is `iphone`.
- iPhone runs use the Mac LAN IP in generated URLs so the device can reach RPC, explorer, and subgraph services.
- If Docker Desktop is not running, start it before running the startup script.
