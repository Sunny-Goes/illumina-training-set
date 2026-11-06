# illumina-training-set

Curated **canary codebases** for evaluating [illumina](https://github.com/Sunny-Goes/azimo), an
automated smart-contract auditor — consumed by [illumina-lab](https://github.com/Sunny-Goes/illumina-lab),
the evaluation harness.

## Why this exists

To measure an automated auditor you need codebases where you *know* which bugs exist. A canary is
such a codebase: a real protocol pinned at a commit where known bugs are **provably present** —
found in the wild (published Immunefi competitions, audits), later patched, and curated here with
the evidence to prove it. This repo holds the curation: the ground truth, the fix patches, known-good
exploits, and the certification that ties them together. The audited code itself is fetched by
commit SHA from its repo (a fork under this org, or upstream).

## How it works, end to end

```
            this repo                          illumina-lab + illumina
┌───────────────────────────┐
│ 1. CURATE                 │   bugs.json (ground truth: files, severity, fix patch, sites)
│    pick a codebase + a    │   canary.json (the pointer: snapshot commit, pack binding)
│    commit where N known   │   fixes/    (one minimal patch per bug)
│    bugs are present       │   reference/ (one known-good exploit per bug)
│                           │
│ 2. CERTIFY (CI)           │   per bug: replay the reference exploit on the pinned snapshot
│    ci/certify.sh          │   → must WIN; replay with the fix applied → must DIE.
│                           │   Red CI = the ground truth is wrong, never the auditor.
└───────────┬───────────────┘
            ▼
│ 3. RUN                    │   illumina audits the pinned snapshot — it never sees anything
│                           │   from step 1 (the leak rule, below).
            ▼
│ 4. JUDGE                  │   each PoC the auditor produced is replayed twice: on the
│    the counterfactual     │   vulnerable snapshot and on the snapshot + each bug's fix.
│    judge                  │   Wins unpatched + dies on bug X's fix ⇒ the PoC exploits bug X.
└───────────────────────────┘
```

The judge is **counterfactual** — attribution is an experiment, not a guess: if an exploit stops
working exactly when one bug's fix is applied, that exploit depended on that bug. No LLM, no
fuzzy matching on code locations.

## What a canary carries

One directory per codebase-at-commit, `canaries/<codebase>/<snapshot>/`:

```
├── README.md       # the curation record: why this codebase, where each bug came from
│                   # (report links, fix commits), how presence at the snapshot was verified,
│                   # certification results — everything needed to re-derive the entry
├── canary.json     # the pointer the lab may see: id, pack/target binding, snapshot SHA, links
├── bugs.json       # the ground truth (judge-side only): per bug — id, files, severity,
│                   # win-condition mapping, provenance, fix patch, sites, reference PoC
├── fixes/          # one minimal patch per bug — applies cleanly at the snapshot
└── reference/      # one known-good exploit per bug (a forge test that passes while the bug
                    # is present and fails once fixed), with its own README
```

`sites` per bug (`{file, lines, kind, function}`) locate the bug precisely at the snapshot —
used for finer grading and coverage analysis. `lines` are 1-based ranges in the *pre-fix* code.

## Authoring a new canary

Read **[AUTHORING.md](AUTHORING.md)** — the mechanical, AI-executable methodology, with a
checklist. Two tracks:

- **historical** — curate real findings from a finished program (the reference implementation is
  `canaries/vechain-stargate/hayabusa`, from VeChain's finished Immunefi competition);
- **seeded** — plant a bug ourselves; the fix is the revert of the seed commit (reference:
  `canaries/honk/*`).

## Certification

`ci/certify.sh <canary-dir>` certifies every bug that carries a fix and a reference exploit:
win on vulnerable, die on fixed — verified by rebuilding the workspace from nothing but the
canary data (the snapshot subtree fetched at the pinned SHA, dependencies at pinned revisions).
The GitHub workflow runs it on every change under `canaries/**` — ground truth is a validated
artifact, not prose.

Run it locally (needs [foundry](https://getfoundry.sh) and Python 3):

```bash
# with the lab CLI installed (pip install git+https://github.com/Sunny-Goes/illumina-lab.git):
ci/certify.sh canaries/vechain-stargate/hayabusa

# fast path against an existing PoC workspace; LAB_CMD points at a local lab checkout:
CERTIFY_WORKSPACE=/path/to/workspace LAB_CMD="uv run --directory /path/to/illumina-lab illumina-lab" \
  ci/certify.sh canaries/honk/precompile-success-unchecked
```

`SUBDIR` overrides which in-repo subtree becomes the audit target (default: `target_subdir` in
canary.json, else `barretenberg/sol`); `STRIP`/`TARGET_DIR` tune patch application.

## The rules

- **Presence is proven, not trusted.** Every shortlisted bug is trigger-verified at the snapshot
  (a code shape is not enough), and its fix patch must apply cleanly at the pin.
- **Ground truth never reaches the auditor.** `bugs.json`, `fixes/`, `reference/` are judge-side:
  they live outside every fetched code path, and the snapshot predates any documentation of the
  bugs in the fetched repos. `canary.json` carries no ground truth — a `bugs` key there fails loudly.
- **Disclosure.** Nothing here is live-and-unpatched: only finished programs and deployed fixes.
- **Forks for durability.** Upstream pins are allowed, but a SHA that stops being reachable gets forked.

## Status

- `canaries/honk/` — four seeded dev-target entries (`honk-canonical-no-field-check`,
  `honk-precompile-success-unchecked`, `honk-msm-loop-past-bounds`, `honk-all-canaries`),
  transcribed from azimo's live canary suite. Seeded-track reference.
- `canaries/vechain-stargate/hayabusa` — the first **historical** canary: VeChain Stargate from
  the finished Immunefi audit competition (2025-11), 2 certified bugs (high severity, ~49 deduped
  reports), full curation record in its README. Historical-track reference implementation.
- Next: `hayabusa-r2` (the release-introduced bug F-2026-14785 lives there), then plether once its
  competition fixes are public — plether is also prism-era in size.
