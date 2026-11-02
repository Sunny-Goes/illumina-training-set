# precompile-success-unchecked

**Type:** seeded dev-target (methodology-lite) — one bug planted on the pinned v4 UltraHonk verifier, on a branch of the `Sunny-Goes/aztec-packages` fork.

- **Snapshot**: `13060089504cfcdc92e74a9992a3e64f3c4b0e91` (`barretenberg/sol/src/honk`, 10 in-scope `.sol` files)
- **Bug**: `utils.sol:ecMul` — the ecMul staticcall's success flag is no longer checked (see `bugs.json`).
- **Source**: azimo's live canary suite (`tests/test_honk_canaries_live.py`) — the ground-truth table transcribed here.

Curated as a development target for illumina-lab v0; not an audit-derived canary. The ground truth lives in this repo, never in the fork's fetched scope — the detector cannot reach it.
