# Reference PoC — ecmul-success-unchecked

A curated, known-good exploit for this canary's bug, used to certify the canary and to self-test
the lab's counterfactual judge (the known-answer control: the judge must return
`confirmed:ecmul-success-unchecked` for it).

## Provenance

Produced by azimo's PoC pipeline on the curated input
`azimo/experiments/poc_inputs/precompile-success-unchecked.json`, run
`.cache/poc/run-precompile-success-unchecked-2/6634cac259f9/attempt-1/` (recorded `ok: true`),
and frozen here after the counterfactual pair below was verified manually. Not an agent run's
output — a reviewed, archived artifact.

- `PocTest.sol` — the exploit: calls the target's `ecMul` with the off-curve point `(1,3)` and
  asserts it does NOT revert and consumes the failed precompile's stale output buffer.
- `EcMulControl.t.sol` — the honest control: the raw precompile rejects `(1,3)`, and the target's
  `ecMul` matches the precompile on a valid point.
- `foundry.toml` — the workspace's project file (target remapped as `target/=lib/target/`,
  forge-std under `dependencies/`).

## Verified counterfactual (2026-11-05)

- Unpatched replay: `test_ecMul_offCurvePoint_doesNotRevert_returnsStaleOutputBuffer` **PASS**
  (the bug is present — no revert, stale buffer consumed).
- Patched replay (`fixes/ecmul-success-unchecked.patch`, `--strip 3 --target-dir lib/target`):
  the SAME test **FAILS** with `target ecMul reverted on the off-curve point (1,3)` — the restored
  success check kills the exploit.

## Reconstructing a replayable workspace

This directory carries only the experiment files, not a full Foundry workspace (dependencies and
the target checkout are large). To replay: take any PoC workspace materialized for this target
(e.g. an archived `.cache/poc/*/attempt-1/workspace`, or one built from the pack's PoC scaffold),
replace its `test/` files with the ones here, and run the lab's `judge/replay.py` on it — with and
without the fix patch. The target sources must be the canary snapshot
(`13060089504cfcdc92e74a9992a3e64f3c4b0e91`, `barretenberg/sol` subtree at `lib/target`).
