# canonical-no-field-check

**Type:** seeded dev-target (methodology-lite) — one bug planted on the pinned v4 UltraHonk verifier, on a branch of the `Sunny-Goes/aztec-packages` fork.

- **Snapshot**: `d82fda6fc08370dfeef3a63df94de16fcf5584a2` (`barretenberg/sol/src/honk`, 10 in-scope `.sol` files)
- **Bug**: `Transcript.sol:generateEtaChallenge` — the `require(publicInputs[i] < P)` canonical check is gone (see `bugs.json`).
- **Source**: azimo's live canary suite (`tests/test_honk_canaries_live.py`) — the ground-truth table transcribed here.

Curated as a development target for illumina-lab v0; not an audit-derived canary. The ground truth lives in this repo, never in the fork's fetched scope — the detector cannot reach it.
