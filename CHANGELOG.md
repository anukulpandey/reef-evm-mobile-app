# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed

- Polished the `Send Token` screen shell to match the `Swap Tokens` screen more closely.
- Simplified and refined the auth lock screen styling and unlock card behavior.
- Hid `Developer Settings` unless `Developer Mode` is explicitly enabled.
- Added a persisted fiat currency selector in Settings and applied it to portfolio, token, and pool fiat displays.

## [2026-03-19]

### Added

- Multi-account wallet management with account selection, rename, export, and improved account actions.
- Wallet activity tab sourced from explorer and subgraph activity data.
- Token creator flow with developer-mode gated navigation.
- Dark mode support with persisted theme preference.
- Reef-style loading states for wallet, pools, activity, and detail views.
- Transaction confirmation flow with password approval before broadcast.
- Pool discovery, pool detail, liquidity, and swap flows backed by subgraph and Reefswap-style DEX logic.
- Telegram notification helper script for local operator workflows.
- Production-oriented README covering config surfaces, local stack usage, and release setup.

### Changed

- Reworked wallet, send, settings, and swap UI to align more closely with the Reef mobile-app and Reefswap references.
- Replaced hardcoded pool data with subgraph-backed pool discovery.
- Improved token icon resolution and token/pool presentation across wallet and pool screens.
- Added compact balance formatting using `k`, `M`, `B`, and `T` notation in wallet and portfolio surfaces.
- Moved token creation out of the pools header and behind a dedicated developer-mode flow.
- Improved password, export, and confirmation modals to better match the app theme in both light and dark mode.
- Updated the signing screen to use a more wallet-like review layout instead of a raw debug-style form.
- Improved send and swap input handling, slider affordances, and loading feedback.

### Fixed

- Fixed transaction construction issues around gas estimation and RPC rejection handling for native transfers.
- Fixed several send/swap screen styling regressions where focused inputs turned white or did not match the active theme.
- Fixed export-account cancel crashes caused by dialog lifecycle/controller disposal issues.
- Fixed dark-mode inconsistencies across home, send, settings, auth, and confirmation flows.
- Fixed account-balance display overflows by introducing compact notation.
- Fixed select-account and other bottom sheet overflow issues on smaller screens.
- Fixed local DEX/bootstrap issues by aligning deployment, subgraph wiring, and Reefswap-compatible scripts.
