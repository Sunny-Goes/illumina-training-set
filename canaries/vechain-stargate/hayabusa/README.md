# vechain-stargate / hayabusa — curation record

**Type:** historical canary (audit-competition-derived) — the first one; the worked example for `AUTHORING.md`.

Curation performed 2026-11-06. This file is the reproducibility record: every claim below is backed by a link, a commit, or a check you can re-run.

## Sources

- **Competition**: [Audit Comp | VeChain | Stargate Hayabusa](https://immunefi.com/audit-competition/audit-comp-vechain-stargate-hayabusa/) — ran 2025-11-10 → 2025-11-24, [status: Finished](https://immunefi.com/audit-competition/audit-comp-vechain-stargate-hayabusa/leaderboard/), ~1,920 LOC in scope, rewards in USDT. [Scope page](https://immunefi.com/audit-competition/audit-comp-vechain-stargate-hayabusa/scope/) carries the reward table (→ win conditions).
- **Pin**: [immunefi-team/audit-comp-vechain-stargate-hayabusa](https://github.com/immunefi-team/audit-comp-vechain-stargate-hayabusa), tip `e9c0bc9b0f24dc0c44de273181d9a99aaf2c31b0` (2025-11-07). Squashed snapshot — no history on this side.
- **Ground truth (97 published findings)**: [Past-Audit-Competitions/vechain-or-stargate-hayabusa](https://github.com/immunefi-team/Past-Audit-Competitions/tree/main/vechain-or-stargate-hayabusa) — one md per report: `<report-id>-sc-<severity>-<slug>.md`, with target file, impact class, code excerpts, and Proof-of-Concept sections.
- **Upstream repo (fix history)**: [vechain/stargate-contracts](https://github.com/vechain/stargate-contracts).
- **Parallel audit**: Hacken, May 2025 — PDF at the competition repo root (`Hacken_Vechain Foundation_[SCA] VeChain _ Stargate _ May 2025 _…pdf`).

## Snapshot correspondence (verified 2026-11-06)

The competition snapshot is blob-for-blob identical to upstream commit
**`93eaa804fe6bdc0afc3edca3a17a89cb3c2365b0`** (2025-11-05, "feat: update contracts to hayabusa release")
for every file under `packages/contracts/contracts/` (checked via `git rev-parse HEAD:<path>` vs
`git rev-parse 93eaa804:<path>` for all entries — zero diffs). So the pin is exact, and upstream
history after `93eaa804` is where fixes are identified (D23).

## Findings inventory and dedup

97 reports: **69 high, 5 medium, 12 low, 10 insight**. Targets: `Stargate.sol` 80, `StargateNFT.sol` 11, `Levels.sol` 4, `MintingLogic.sol` 1, none 1.

Competition reports carry heavy duplication (same bug, many reporters). Two dominant clusters:

- **Cluster A — double-decrease of `delegatorsEffectiveStake` on validator exit (~25 reports, all high).**
  When a delegator has already requested exit and the validator later exits, both `unstake` and
  `_delegate` re-subtract the effective stake → arithmetic underflow → permanent unstake DoS /
  fund freeze. Representative reports:
  [#59386](https://github.com/immunefi-team/Past-Audit-Competitions/blob/main/vechain-or-stargate-hayabusa/59386-sc-high-fund-freeze-from-double-stake-subtraction-when-validator-exits.md),
  #59564, #59723, #59727, #60004, #60334.
- **Cluster B — off-by-one in `_claimableDelegationPeriods` (~24 reports, all high).**
  The `endPeriod > nextClaimablePeriod` boundary lets exited delegations claim rewards for periods
  after exit — theft of unclaimed yield. Representative reports:
  [#59316](https://github.com/immunefi-team/Past-Audit-Competitions/blob/main/vechain-or-stargate-hayabusa/59316-sc-high-off-by-one-unlocks-infinite-vtho-reward-drain-from-ghost-stakes.md),
  #59358, #59361, #59563.
- Remaining ~20 highs: smaller themes (first-period reward loss on pending validators, misc) — not shortlisted.

## Fix mapping (D23, historical track)

Upstream has exactly two contract-touching commits after the snapshot:

| commit | date | message | content |
|---|---|---|---|
| `f7d2259ba0d63f2f56cd338cc3ac1df6e4588f46` | 2025-12-04 | feat: update contracts to hayabusa release (#23) | 75-file release sync — **contains both cluster fixes, entangled** with a transition-period feature and the `StargateNFT` refactor (783 lines) |
| `b8b695b5e71710ede894289a43c4d7d5e9e81d0b` | 2026-01-22 | fix: vulnerability and polish scripts (#27) | **clean 11-line `Stargate.sol` fix**, self-documenting: "F-2026-14785 vulnerability fix" |

Hunk map inside `f7d2259b` (diffed against `93eaa804`, i.e. against the snapshot — extracted hunks
apply by construction):

- **Cluster A fix**: hunks in `unstake` (`@@ -261,23`, `@@ -289,7`) and `_delegate` (`@@ -369,6` … `@@ -451,14`): the `!_hasRequestedExit($, _tokenId)` guard on the EXITED-branch subtraction, plus the helper change (`endPeriod != type(uint32).max && status != DelegationStatus.EXITED`, hunks `@@ -694,7`, `@@ -705,10`).
- **Cluster B fix**: hunks in `_claimRewards` / `_claimableDelegationPeriods` (`@@ -755,14`, `@@ -902,8`, `@@ -916,7`, `@@ -948,6`): `>` → `>=` boundary, the `endPeriod <= lastClaimedPeriod` early return, `lastClaimedPeriod` handling.
- **Not bug fixes** (must be excluded from the per-bug patches): the `isInTransitionPeriod` transition-period feature (interleaved in the same hunks — manual hunk splitting required), `requestDelegationExit` changes (`@@ -530,7`, `@@ -562,12`), the whole `StargateNFT/` refactor.

This is the squashed-fixes case D23 anticipates: per-bug patches are hunk-extracted from the
release diff, then re-verified with `git apply --check` against the snapshot and certified.

## Shortlist (2 bugs certified, all `Stargate.sol`)

| bug id | severity | impact class | fix | track |
|---|---|---|---|---|
| `effective-stake-double-decrease-on-exit` | high | permanent freezing of funds | extracted from `f7d2259b` (guard + `_hasRequestedExit` helper + floor-at-zero) | historical |
| `claimable-periods-off-by-one-post-exit` | high | theft of unclaimed yield | extracted from `f7d2259b` (`endPeriod <= lastClaimedPeriod` guard + `>` → `>=` + cursor advance on zero-claim) | historical |

**Dropped: `lastclaimed-period-reset-double-claim` (F-2026-14785).** Its fix `b8b695b5` targets the
*post-release* code state (the finding is from 2026, against `f7d2259b`-era logic). Trigger-level
analysis at the snapshot shows the reset path yields `claimableAmount == 0` (the cursor reset is
unreachable with nonzero claims there) — the bug is a child of the release, not of the snapshot.
**Methodology lesson now in AUTHORING.md: presence-at-snapshot must be trigger-verified, not
code-shape-verified.** The "found after the competition" case stays available via the StargateNFT
findings (see Future material).

## Spike validation (2026-11-06) — canary feasibility proven end-to-end

Done in a scratch forge workspace (`/tmp/vechain-curation/poc-ws`, not committed) with the lab's
real CLI (`illumina-lab counterfactual`):

- **Workspace recipe**: `lib/target/` = `packages/contracts` subtree root (relative imports of the
  in-tree mocks require it), deps pinned soldeer-style like honk — forge-std 1.9
  (`3b20d60d…`), `openzeppelin-contracts` 5.0.2 (`dbb6104c…`), `openzeppelin-contracts-upgradeable`
  5.0.2 (`b17897bb…`), solc 0.8.20. Snapshot sources compile clean.
- **Harness pattern**: `ERC1967Proxy` + `initialize` (the constructor disables initializers);
  `ProtocolStakerMock` drives validator status/completed periods (`helper__setValidation*` —
  periods are per-validator counters, no block advancement needed); `StargateNFTMock` stands in for
  the NFT (level + token setters, mint); VTHO is a vechain builtin at
  `0x0000…456E65726779` — `vm.etch` a `MyERC20` there and fund the Stargate reward pool.
- **PoC convention**: each test passes while its bug is present, fails once fixed.
  - A (`test_A_double_decrease_locks_unstake`): delegate → delegation ACTIVE → `requestDelegationExit`
    → validator EXITED → `unstake` reverts (panic underflow). **The upstream fix kills it via the
    floor-at-zero in `_updatePeriodEffectiveStake`** — the `!_hasRequestedExit` guard alone does not
    (it returns false once the delegation reads EXITED). Patches must carry the full upstream fix.
  - B (`test_B_post_exit_overclaim`): honest delegator keeps the denominator alive; attacker exits
    with `endPeriod == nextClaimablePeriod`, validator advances, claim pays post-exit periods
    (0.25 VTHO vs 0.05 honest) — the constant per-token effective stake is the numerator that never
    decays. Two-delegator scenarios are the faithful port of the reports' "ghost stake" mechanics.
- **Counterfactual results** (lab CLI, `--strip 3 --target-dir lib/target`):

  | patch | test A | test B |
  |---|---|---|
  | A (`bug-A.patch`, 18+/8−) | **confirmed** (win/fail) | not-specific (win/win) |
  | B (`bug-B.patch`, 9+/3−) | not-specific (win/win) | **confirmed** (win/fail) |

  Full 2×2 specificity: each patch kills exactly its own PoC. Both patches pass
  `git apply --check -p3 --directory lib/target` against the snapshot.
- **Replay commands must be per-bug** (`--command "forge test --match-test test_A_…"`), or one
  workspace per bug (honk style) — otherwise the fixed leg fails on *any* dying test and
  attribution blurs.
- **CWD gotcha**: `uv run --directory <lab> illumina-lab …` changes CWD before the CLI runs —
  always pass absolute paths (this bit once during the spike).

## Integration findings (feed AUTHORING.md)

1. **Report PoCs are Hardhat/TypeScript** (`packages/contracts/test/unit/…`); the lab's replay
   harness is forge-only. Reference PoCs must be **ported to forge** (the `PocTest.sol` pattern from
   honk), recording provenance (report id + reporter handle) in the reference README.
2. **Patch strip/target-dir is per-codebase**: vechain paths are `a/packages/contracts/…` →
   `--strip 3` maps them to `contracts/…` under the PoC workspace's target dir (the pack scaffold
   decides the layout; `certify.sh` already parameterizes `STRIP`/`TARGET_DIR`).
3. **Squashed fixes are the norm upstream** (mirror-repo development — commits reference an
   internal repo, e.g. "align with commit 23125cc"). Hunk extraction + certification is the
   repeatable answer.

## Future material

`StargateNFT.sol` carries 15 findings and a 783-line refactor in `f7d2259b` — candidates for a
second snapshot or an extended canary later.

## Certification — CERTIFIED 2026-11-06

Full reconstruction via `ci/certify.sh` (extended for this canary: `SUBDIR` env override,
all-dependency fetch — vechain needs OpenZeppelin beyond forge-std, per-bug `test/` refresh):

```
SUBDIR=packages/contracts ci/certify.sh canaries/vechain-stargate/hayabusa
→ effective-stake-double-decrease-on-exit — CERTIFIED (wins on vulnerable, dies on fixed)
→ claimable-periods-off-by-one-post-exit — CERTIFIED (wins on vulnerable, dies on fixed)
```

Specificity matrix (from the spike): each patch kills exactly its own PoC; cross-pairs are
`not-specific`. Both patches pass `git apply --check -p3 --directory lib/target` at the snapshot.

## Status

Canary data complete: `canary.json`, `bugs.json` (2 bugs), `fixes/`, `reference/`, certification
green. **Not runnable yet**: the azimo pack/target (`vechain-stargate`/`hayabusa`) is v1 lab-side
work (the forge/ component); the lab's crosscheck validates this entry once the pack exists.
