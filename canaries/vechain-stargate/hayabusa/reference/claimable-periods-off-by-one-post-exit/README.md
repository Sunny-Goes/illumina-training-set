# Reference PoC — claimable-periods-off-by-one-post-exit

Known-good exploit for this canary's bug, ported to forge. Convention: the test **passes while
the bug is present** and **fails once the fix patch is applied** (the counterfactual contract).

## Provenance

Mechanism from the competition reports (all high, cluster of ~24):
[#59361](https://github.com/immunefi-team/Past-Audit-Competitions/blob/main/vechain-or-stargate-hayabusa/59361-sc-high-off-by-one-in-claimabledelegationperiods-allows-claimrewards-to-pay-for-periods-after.md)
(the scenario spec), #59316, #59358, #59563 — Hardhat/TS PoCs ported to forge 2026-11-06
(spike, see the canary README).

## The trigger (faithful to report #59361)

1. An **honest delegator** (Bob) stakes and delegates and never exits — he keeps
   `delegatorsEffectiveStake[validator]` nonzero after the attacker's exit. Without him the
   post-exit periods pay zero and the over-claim is numerically empty.
2. Attacker (Alice) delegates at completedPeriods = 0 (startPeriod 2, lastClaimed 1).
3. One period later she `requestDelegationExit` → the mock sets `endPeriod = 2`, exactly
   `nextClaimablePeriod` — the equal case the `>` boundary misses.
4. Validator advances to completedPeriods = 4.
5. `claimRewards` computes the claimable range as (2, 4) instead of (2, 2): the attacker's
   per-token effective stake never decays, so post-exit periods pay her 0.25 VTHO instead of the
   honest 0.05. The test asserts the over-claim.

## Verified counterfactual (2026-11-06)

`illumina-lab counterfactual` (lab CLI, `--strip 3 --target-dir lib/target`):
unpatched the exploit test **PASSES**; with `fixes/claimable-periods-off-by-one-post-exit.patch`
the same test **FAILS** (claim returns the honest amount). Verdict: `confirmed`. Cross-check
against the sibling bug's patch: `not-specific`.
