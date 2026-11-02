# all-canaries

**Type:** seeded dev-target (methodology-lite) — the study snapshot: all three seeded bugs at once on the pinned v4 UltraHonk verifier, on a branch of the `Sunny-Goes/aztec-packages` fork.

- **Snapshot**: `587c986cb5ca3002343885056f0d198c9d39a107` (`barretenberg/sol/src/honk`, 10 in-scope `.sol` files)
- **Bugs**: all three seeded sites — `Transcript.sol`, `utils.sol`, `BaseHonkVerifier.sol` (see `bugs.json`).
- **Source**: azimo's live canary suite (`tests/test_honk_canaries_live.py`) — the ground-truth table transcribed here.

Curated as a development target for illumina-lab v0; not an audit-derived canary. The ground truth lives in this repo, never in the fork's fetched scope — the detector cannot reach it.
