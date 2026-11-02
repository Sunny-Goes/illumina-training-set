# msm-loop-past-bounds

**Type:** seeded dev-target (methodology-lite) — one bug planted on the pinned v4 UltraHonk verifier, on a branch of the `Sunny-Goes/aztec-packages` fork.

- **Snapshot**: `9b3918484a0adc9c9080764f49170715150ce8ab` (`barretenberg/sol/src/honk`, 10 in-scope `.sol` files)
- **Bug**: `BaseHonkVerifier.sol:batchMul` — the MSM loop runs one iteration past the arrays' bound (see `bugs.json`).
- **Source**: azimo's live canary suite (`tests/test_honk_canaries_live.py`) — the ground-truth table transcribed here.

Curated as a development target for illumina-lab v0; not an audit-derived canary. The ground truth lives in this repo, never in the fork's fetched scope — the detector cannot reach it.
