# illumina-training-set

Curated canary codebases for [illumina](https://github.com/Sunny-Goes/azimo) evaluation — the data repo consumed by [illumina-lab](https://github.com/Sunny-Goes/illumina-lab).

A **canary** is a codebase pinned at a snapshot commit where known, real bugs (from published audits and Immunefi programs) are provably present. This repo holds the curation: methodology, machine-readable ground truth, and the git pointer. The code itself lives in forks under this org (or upstream repos), fetched by SHA.

## What a canary carries

One directory per canary:

```
canaries/<name>/
├── README.md       # methodology: why this codebase, bug sources (audit/Immunefi links),
│                   # snapshot commit and date, how the bugs were validated present
├── bugs.json       # machine-readable ground truth: per bug — id, fix commit, location hunk,
│                   # severity, win-condition mapping
└── canary.json     # the pointer: git url, snapshot sha, in-scope file list
```

## The rules

- **Coexistence is proven, not trusted.** Every bug's pre-fix hunk must appear verbatim at the snapshot commit — checked mechanically, per bug.
- **Ground truth is unreachable by the detector.** This documentation never lives inside the code's fetched scope, and the pinned snapshot commit predates the documentation commit in the fork.
- **Forks for durability.** Upstream pins are allowed, but a SHA that stops being reachable gets forked.

## Status

Empty — the first canary (plether) is curated as part of illumina-lab v1. Development targets before that: the seeded honk canaries on the `Sunny-Goes/aztec-packages` fork.
