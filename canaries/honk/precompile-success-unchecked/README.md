# precompile-success-unchecked

**Type:** seeded dev-target (methodology-lite) — one bug planted on the pinned v4 UltraHonk verifier, on a branch of the `Sunny-Goes/aztec-packages` fork.

- **Snapshot**: `13060089504cfcdc92e74a9992a3e64f3c4b0e91` (`barretenberg/sol/src/honk`, 10 in-scope `.sol` files)
- **Bug**: `utils.sol:ecMul` — the ecMul staticcall's success flag is no longer checked (see `bugs.json`).
- **Source**: azimo's live canary suite (`tests/test_honk_canaries_live.py`) — the ground-truth table transcribed here.

Curated as a development target for illumina-lab v0; not an audit-derived canary. The ground truth lives in this repo, never in the fork's fetched scope — the detector cannot reach it.

## Ground truth v2 — fix patch and counterfactual certification

The bug was seeded in `4fcb3d6` ("stop checking ecMul precompile success"), which removed the
`if iszero(success) { revert(0, 0) }` guard in `utils.sol:ecMul`. `fixes/ecmul-success-unchecked.patch`
re-inserts exactly that guard and nothing else; it applies cleanly at the snapshot
(`13060089504cfcdc92e74a9992a3e64f3c4b0e91`), which also carries the later reachability changes.

Regenerate the patch with:

```bash
R=<a clone of Sunny-Goes/aztec-packages at the snapshot>
mkdir -p a/barretenberg/sol/src/honk b/barretenberg/sol/src/honk
git -C "$R" show 13060089504cfcdc92e74a9992a3e64f3c4b0e91:barretenberg/sol/src/honk/utils.sol \
  | tee a/barretenberg/sol/src/honk/utils.sol > b/barretenberg/sol/src/honk/utils.sol
# edit b/.../utils.sol: insert after the ecMul staticcall line (line 171):
#         if iszero(success) {
#             // TODO: meaningful error
#             revert(0, 0)
#         }
git diff --no-index a b | sed 's|a/a/|a/|g; s|b/b/|b/|g' > fixes/ecmul-success-unchecked.patch
git -C "$R" apply --check fixes/ecmul-success-unchecked.patch   # must succeed
```

The `sites` entry marks the unguarded region (`utils.sol` lines 166–178 at the snapshot — the
staticcall and the unchecked result copy, function `ecMul`); the fix only *adds* lines, hence
`kind: "context"`.

Manual certification (once the reference PoC is in place): run the reference PoC against the
snapshot — it must WIN; apply the fix patch to the target sources and re-run the *same* PoC
unchanged — it must FAIL. The same pair of replays, run by the lab's judge on agent-produced
PoCs, attributes a PoC to this bug with no LLM and no line matching.
