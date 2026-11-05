# illumina-training-set

Curated canary codebases for [illumina](https://github.com/Sunny-Goes/azimo) evaluation — the data repo consumed by [illumina-lab](https://github.com/Sunny-Goes/illumina-lab).

A **canary** is a codebase pinned at a snapshot commit where known, real bugs (from published audits and Immunefi programs) are provably present. This repo holds the curation: methodology, machine-readable ground truth, and the git pointer. The code itself lives in forks under this org (or upstream repos), fetched by SHA.

## What a canary carries

One directory per canary, grouped by codebase:

```
canaries/<codebase>/<snapshot>/
├── README.md       # methodology: why this codebase, bug sources (audit/Immunefi links),
│                   # snapshot commit and date, how the bugs were validated present
├── bugs.json       # machine-readable ground truth: per bug — id, files, severity,
│                   # win-condition mapping, source, notes
└── canary.json     # the binding: pack + target + snapshot sha — azimo's target manifest
                    # owns repo/path/in-scope; the validator asserts the shas agree
```

A canary is one codebase at one commit. Snapshots group under `canaries/<codebase>/`
so a codebase can carry several snapshots — e.g. when no single commit has all its
known bugs coexisting, each snapshot carries the subset that does.

## Bug entries v2 — counterfactual ground truth

Bug entries may carry additional optional fields supporting the lab's **counterfactual judge**
(an agent's PoC is attributed to bug X when it wins on the vulnerable snapshot and *fails* on the
same snapshot with X's fix applied — no LLM, no line matching):

- `fix` — path to a patch (relative to the canary dir) that repairs **only this bug** and applies
  cleanly at the snapshot (`git apply --check`). For seeded canaries this is the revert of the seed
  commit, restricted to the bug's files; for historical canaries, the fix commit's diff, backported
  if needed. Fixes must be independently applicable on multi-bug snapshots.
- `sites` — optional list of `{file, lines, kind, function}` locating the bug at the snapshot for
  detection-level grading and coverage prefiltering. `lines` are 1-based inclusive ranges at the
  snapshot. `kind`: `modified`/`deleted` (lines the fix changes or removes) or `context` (the fix
  only *adds* code — e.g. a missing check — so the site is the unguarded region around the
  insertion point). `function` is the enclosing function when known.
- `reference_poc` — optional path to a curated, known-good exploit used to certify the canary
  (wins on vulnerable, fails on patched) and to self-test the judge.

These fields are **judge-side ground truth**: `canary.json` is unchanged, execution stages never
see them, and `fixes/` / `reference/` live outside every fetched sparse path, like `bugs.json`.

## Certification (CI)

`ci/certify.sh <canary-dir>` certifies every bug carrying `fix` + `reference_poc`: the reference
exploit must win on the vulnerable snapshot and die on the fixed variant (the lab's
`illumina-lab counterfactual` verdict must be `confirmed`). It reconstructs a Foundry
workspace from the canary data alone (sparse, blob-filtered fetch of the snapshot + forge-std at
the pinned rev) and replays on scratch copies — no archived artifacts needed, no LLM. The GitHub
workflow `.github/workflows/certify.yml` runs it on changes to `canaries/**` or `ci/**` and makes
ground truth a validated artifact instead of curation prose. Locally, `CERTIFY_WORKSPACE=<dir>`
skips reconstruction for a fast check against an existing PoC workspace; `LAB_CMD` overrides how
the lab CLI is invoked (e.g. `uv run --directory /path/to/illumina-lab illumina-lab`).

## The rules

- **Coexistence is proven, not trusted.** Every bug's pre-fix hunk must appear verbatim at the snapshot commit — checked mechanically, per bug.
- **Ground truth is unreachable by the detector.** This documentation never lives inside the code's fetched scope, and the pinned snapshot commit predates the documentation commit in the fork.
- **Forks for durability.** Upstream pins are allowed, but a SHA that stops being reachable gets forked.

## Status

Four seeded dev-target entries for illumina-lab v0, under `canaries/honk/` (`honk-canonical-no-field-check`, `honk-precompile-success-unchecked`, `honk-msm-loop-past-bounds`, `honk-all-canaries` — four snapshots of the one codebase, since azimo seeded its bugs on four branches) — methodology-lite, transcribed from azimo's live canary suite. The first audit-derived canary (plether) is curated as part of illumina-lab v1.
