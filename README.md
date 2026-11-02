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

## The rules

- **Coexistence is proven, not trusted.** Every bug's pre-fix hunk must appear verbatim at the snapshot commit — checked mechanically, per bug.
- **Ground truth is unreachable by the detector.** This documentation never lives inside the code's fetched scope, and the pinned snapshot commit predates the documentation commit in the fork.
- **Forks for durability.** Upstream pins are allowed, but a SHA that stops being reachable gets forked.

## Status

Four seeded dev-target entries for illumina-lab v0, under `canaries/honk/` (`honk-canonical-no-field-check`, `honk-precompile-success-unchecked`, `honk-msm-loop-past-bounds`, `honk-all-canaries` — four snapshots of the one codebase, since azimo seeded its bugs on four branches) — methodology-lite, transcribed from azimo's live canary suite. The first audit-derived canary (plether) is curated as part of illumina-lab v1.
