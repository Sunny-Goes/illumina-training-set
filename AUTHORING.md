# AUTHORING — how to author a canary

Audience: an AI agent or a human curator. Every step is mechanical: commands plus a pass/fail
check. If a step cannot be checked, it is not done.

A **canary** is one codebase at one commit (the *snapshot*) plus its ground truth: a set of bugs,
each with a fix patch, bug sites, and a certified reference PoC. Two curation tracks:

- **seeded** — we plant the bug ourselves; the fix reverts the seed commit (honk). Lite variant of
  this guide: skip fix identification; everything else applies.
- **historical** — real findings from a finished audit/competition, real fixes from the project's
  history (vechain-stargate). This guide covers the historical track end-to-end.

Reference implementations: `canaries/honk/precompile-success-unchecked` (seeded),
`canaries/vechain-stargate/hayabusa` (historical — its README is a worked curation record).

## 1. Choosing the codebase and the snapshot

Rules, all mandatory:

1. **Solidity, pack-sized.** v0: the in-scope source must fit one illumina pack (~2k LOC,
   honk ≈ 10 files). Bigger codebases wait for the prism.
2. **Public ground truth.** Published findings with severities and impact classes
   (Immunefi's `Past-Audit-Competitions` archive: one md per report,
   `<id>-sc-<severity>-<slug>.md`). Prefer finished competitions/audits with fixes deployed.
3. **Disclosure rule.** Never publish a canary (patches, reference PoCs) for a live program or
   unpatched bugs. The training set is public; certification proves exploitability.
4. **The pin rule.** Every shortlisted bug must be *present at the snapshot* — and
   **trigger-verified, not code-shape-verified**: absent-looking code is not enough; trace the
   trigger path until you can explain how the exploit fires at the snapshot (the F-2026-14785
   lesson: its fix referenced a finding against a *later* code state — dropped). Also verify no
   shortlisted bug was *introduced* by commits after the pin.
5. **Separable fixes.** Each bug's fix must be isolable as one patch applying cleanly to the
   snapshot (see §4). If the history can't yield that, drop the bug or the codebase.
6. **Enumerable fix history.** A public upstream repo whose post-snapshot commits can be mapped
   to fixes.

Snapshot correspondence check (competition repos are squashed snapshots — bind them to upstream):

```bash
# for every in-scope file: the competition blob must equal the upstream blob at <CORR>
for f in $(git -C comp-repo ls-tree -r --name-only HEAD <in-scope-dir>); do
  a=$(git -C comp-repo rev-parse HEAD:$f)
  b=$(git -C upstream rev-parse <CORR>:$f 2>/dev/null || echo MISSING)
  [ "$a" = "$b" ] || echo "DIFFERS: $f"
done   # zero output = exact correspondence
```

Record `<CORR>` (the upstream commit matching the snapshot) in the canary README.

## 2. Inventory and dedupe the findings

- Severity from the filename; target file from the report's `Target:` field; count per file.
- Cluster by *mechanism*, not by title keywords alone — read at least one full report per
  candidate cluster. Competition sets dedupe heavily (vechain: 97 reports → 2 dominant clusters).
- Shortlist 3–5 bugs: high/critical, function-isolated (the whole mechanism in one or two
  functions), each with a runnable PoC section in at least one report.

## 3. Identifying the fix commits

Per shortlisted bug:

1. **Known fix commit** (report, advisory, or changelog names it): verify it touches the reported
   function and nothing conceptually unrelated.
2. **Unknown**: PoC-guided bisect — `git bisect run <harness>` along first-parent history with the
   reference PoC as the test; the first commit where the PoC stops passing is the fix. (Needs the
   PoC first — see §6; reorder steps freely, record the actual order in the README.)
3. **Ancestry check**: `git merge-base --is-ancestor <snapshot> <fix-commit>` — the fix must
   descend from the pin.
4. **Squash awareness**: mirror/develop-elsewhere repos land fixes inside giant release-sync
   commits. Then the fix is a *hunk subset* of that commit's diff (§4). vechain's `f7d2259b`
   (75 files, two bug fixes + a feature) is the worked example.

## 4. Producing the per-bug patch

1. Diff the fix against the snapshot: `git diff <CORR> <fix-commit> -- <file>`. Hunks apply to the
   snapshot by construction.
2. **Entanglement**: drop unrelated lines sharing the hunks (features, events, refactors).
   Hand-edit a copy of the snapshot file, then regenerate the diff:
   `git diff --no-index a/<repo-path> b/<repo-path>` with full repo-relative paths (sed the
   prefixes into shape — the honk README has the recipe).
3. **Full-fix rule**: carry *every* hunk the upstream fix needs to kill the exploit. Intuition
   about which hunk matters is unreliable — vechain's bug A dies only because of the floor-at-zero
   hunk, not the obvious guard. Certification (§7), not reading, decides sufficiency.
4. **Semantics-minimal**: no renames, moves, or signature changes — a patch that breaks the PoC's
   build reads as `patch-incompatible` at judge time, never as a kill.
5. Verify: `git apply --check -p<N> --directory <target-dir>` against a snapshot materialization.
   N and the target dir depend on the codebase layout (vechain: `-p3 lib/target`; a full clone:
   `-p1 .`).
6. Multi-bug commits → split into one commit per bug in the curation fork. Partial fixes → find
   the minimal killing range. Truly inseparable bugs (same lines) → one bug entry with a note.

## 5. sites

Derive from the fix diff's preimage: each `@@ -a,b @@` hunk gives snapshot line ranges;
`kind: "context"` when the fix only *adds* lines (the range brackets the insertion point);
`function` is the enclosing function at the snapshot. Cross-check against the report's quoted
code.

## 6. Reference PoC (forge)

The lab's judge replays forge workspaces only; report PoCs may be Hardhat/TS — port them.
Convention: **the test passes while the bug is present and fails once the fix is applied.**

Harness recipe (proven in the vechain spike):

- `lib/target/` = the target subtree root *such that in-tree mocks' relative imports resolve*
  (vechain mocks import `../../contracts/…` → the layout must keep the `contracts/` segment).
  Dependencies pinned soldeer-style in `foundry.toml` (`version/git/rev`; forge-std + the exact
  OpenZeppelin versions from the project's own config); `solc_version` from the project config.
- Upgradeables: deploy implementation + `ERC1967Proxy` + `initialize` (constructors disable
  initializers).
- Protocol state is driven through the in-tree mocks' `helper__*` setters (validator status,
  completed periods — no block/time plumbing unless the code is truly time-based).
- Chain builtins at fixed addresses (vechain's VTHO at `0x0000…456E65726779`): `vm.etch` a mock
  ERC20 there; fund the contract under test.
- **Port the report's trigger faithfully**: preconditions matter (e.g. `endPeriod ==
  nextClaimablePeriod`; a second, honest delegator keeping the reward denominator alive).
- Add an honest-control test file where valuable (the `EcMulControl` pattern).
- **Per-bug replay commands**: name tests `test_<bug>_…` and certify with
  `forge test --match-test test_<bug>_…`; otherwise one dying test fails the whole run and
  attribution blurs.

## 7. Certification

```bash
ci/certify.sh <canary-dir>     # per fix+reference-carrying bug: reference PoC must WIN on the
                               # vulnerable snapshot and DIE on the fixed variant
```

- Certification proves: the bug is exploitable at the snapshot; the patch kills it; the patch
  touches nothing else the PoC needs.
- `STRIP`/`TARGET_DIR` env vars parameterize the workspace layout (PoC workspace: `3` /
  `lib/target`; full clone: `1` / `.`).
- Use absolute paths when invoking through `uv run --directory` — it changes CWD before the CLI
  runs.
- A bug that cannot be certified stays in the canary uncertified (recorded in the README) or is
  dropped. `bugs.json` rows with `fix` but no `reference_poc` are *uncertified* ground truth.

## 8. The canary README (reproducibility record)

One per canary directory. Template — see `canaries/vechain-stargate/hayabusa/README.md`:

1. **Sources** — competition/audit links, both repos, all commits with dates.
2. **Snapshot correspondence** — the check from §1 and its result.
3. **Inventory + dedup** — counts, clusters, representative report ids with links.
4. **Fix mapping** — table: bug → fix commit(s) → extraction notes (entanglement, splits).
5. **Shortlist** — per-bug: id, severity, impact class, fix source, track (historical/authored).
6. **Dropped candidates** — with reasons (the F-2026-14785 entry is the model).
7. **Certification results** — verdicts, dates, and the specificity matrix (every patch × every
   reference PoC must confirm its own bug and be `not-specific` on the others).

## Checklist

- [ ] codebase: Solidity, pack-sized, finished program, public findings
- [ ] snapshot correspondence verified blob-for-blob; `<CORR>` recorded
- [ ] findings inventoried, deduped, 3–5 shortlisted
- [ ] per bug: trigger verified at the snapshot (not just code shape)
- [ ] per bug: fix commit identified, ancestry-checked
- [ ] per bug: patch extracted, entanglement removed, full-fix rule honored,
      `git apply --check` passes at the snapshot
- [ ] sites derived from preimage hunks, cross-checked against reports
- [ ] reference PoCs ported to forge; pass unpatched, fail patched, per-bug replay commands
- [ ] `ci/certify.sh` CERTIFIED; specificity matrix recorded
- [ ] README written from the §8 template; dropped candidates recorded
- [ ] disclosure rule honored — nothing in the repo is live-and-unpatched

## 9. Schema reference

One canary directory per codebase-at-commit: `canaries/<codebase>/<snapshot>/`.
The lab validates both files with `extra="forbid"` — an unknown field fails loud at load time.

### `canary.json` — the pointer (leak-safe; what the execution side may see)

| field | required | semantics |
|---|---|---|
| `id` | yes | `<codebase>-<snapshot>`, kebab-case; must equal the directory path |
| `pack` | yes | the azimo pack this canary binds to (kebab) |
| `target` | yes | the pack's target manifest name (kebab) |
| `snapshot_sha` | yes | full 40-hex commit of the codebase at the pin; cross-checked against the engine's target manifest |
| `links` | no | provenance URLs (upstream repo first — certification reads `links[0]` as the fetch remote) |
| `notes` | no | free text |

Never a `bugs` key — the split is enforced: a `canary.json` carrying ground truth fails loudly.

Certification-side, optional (used by `ci/certify.sh` reconstruction): `target_subdir` — the
in-repo subtree materialized as the workspace target (default `barretenberg/sol`; vechain:
`packages/contracts`). *Pending a lab schema addition; today it is certification metadata only.*

### `bugs.json` — the ground truth (judge-side only)

A list of rows:

| field | required | semantics |
|---|---|---|
| `id` | yes | kebab-case; unique within the canary |
| `files` | yes | ≥1 repo-relative paths of the vulnerable files at the snapshot (root cause *and* manifestation) |
| `severity` | no | Immunefi vocabulary: `critical`/`high`/`medium`/`low`/`informational` (empty = unrecorded) |
| `win` | no | the reward-table row expected to catch it (Immunefi-style impact id); cross-checked against the pack's win table |
| `source` | no | provenance: report ids/links, audit name, or "seeded" + fork commit |
| `notes` | no | the mechanism in one sentence |
| `fix` | attribution | repo-relative fix patch (§4); empty = not counterfactually attributable |
| `reference_poc` | certification | directory with the forge PoC (§6); empty = uncertified |
| `sites` | no | list of `{file, lines, kind, function}` — §5; `lines` are 1-based `[start, end]` ranges in the pre-fix snapshot |

Attribution needs `fix`; certification needs `fix` + `reference_poc`. A row with neither is a
recorded-but-unverifiable bug — allowed, flagged in the README.
