# Reference PoC — effective-stake-double-decrease-on-exit

Known-good exploit for this canary's bug, ported to forge. Convention: the test **passes while
the bug is present** and **fails once the fix patch is applied** (the counterfactual contract).

## Provenance

Mechanism from the competition reports (all high, cluster of ~25):
[#59386](https://github.com/immunefi-team/Past-Audit-Competitions/blob/main/vechain-or-stargate-hayabusa/59386-sc-high-fund-freeze-from-double-stake-subtraction-when-validator-exits.md)
(@humanitia), #59564, #59723, #59727, #60004, #60334 — Hardhat/TS PoCs ported to forge
2026-11-06 (spike, see the canary README).

## The trigger (faithful to the reports)

1. Stake + delegate (validator ACTIVE). The delegation must be **active** before the exit request
   — exiting in the delegation's own period takes the pending-withdraw path and resets instead.
2. `requestDelegationExit` — first decrease of `delegatorsEffectiveStake[validator]`.
3. Validator exits (mock `helper__setValidatorStatus`).
4. `unstake` hits the EXITED branch and decreases **again** — arithmetic underflow (panic 0x11),
   funds permanently locked. The test expects that revert.

## What the fix must contain (learned at certification)

The `!_hasRequestedExit` guard alone does **not** kill this PoC — once the delegation reads
EXITED, the helper returns false and the second decrease still runs. The killing hunk is the
floor-at-zero in `_updatePeriodEffectiveStake`. The patch carries the full upstream fix
(guard + helper + floor), extracted from `f7d2259b`.

## Verified counterfactual (2026-11-06)

`illumina-lab counterfactual` (lab CLI, `--strip 3 --target-dir lib/target`):
unpatched the exploit test **PASSES**; with `fixes/effective-stake-double-decrease-on-exit.patch`
the same test **FAILS** (`unstake` succeeds). Verdict: `confirmed`. Cross-check against the
sibling bug's patch: `not-specific`.
