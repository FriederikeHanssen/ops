# GitHub permissions

Who can open a PR and who can merge, for this repo and for
[`nf-core/.github`](https://github.com/nf-core/.github) — the two repos involved
in the shared Renovate preset (see
[`docs/agents/renovate.md`](agents/renovate.md)).

Verified against the GitHub API. Team membership changes, so re-derive with the
commands below rather than trusting the counts.

## Org baseline

- Default repository permission for org members: **read**
- Members cannot create repositories
- Org-wide ruleset `TEMPLATE` protects `refs/heads/TEMPLATE` (deletion,
  non-fast-forward, update), with one team allowed to bypass. It does not apply
  to `main`/`master`.

## `nf-core/ops` (private)

| Team               | Permission |
| ------------------ | ---------- |
| `core`             | admin      |
| `infrastructure`   | maintain   |
| `ops`              | maintain   |
| `maintainers`      | triage     |
| `special_transfer` | pull       |

**Opening a PR:** anyone with write access, which here means `core`,
`infrastructure`, and `ops`. The repo is private, so there is no outside-fork
contribution path — `maintainers` has triage only and cannot push branches.

**Merging to `main`** requires all of:

- 1 approving review
- review from a **code owner** — `.github/CODEOWNERS` is `* @edmundmiller @maxulysse @nf-core/infrastructure`
- the `pre-commit` status check passing

Admins are **not** exempt (`enforce_admins: false` means the rules still apply to
them for review purposes; force pushes are currently allowed).

## `nf-core/.github` (public)

| Team               | Permission |
| ------------------ | ---------- |
| `core`             | admin      |
| `special_transfer` | pull       |

**Opening a PR:** anyone. It is public, so non-members can fork and open PRs.
Direct branch pushes require write access, which is `core` only — there are no
direct collaborators.

**Merging:** `core` (19 members). `master` has **no branch protection and no
ruleset**: no required reviews, no required checks, and no CODEOWNERS file. A
`core` member can push straight to `master`.

That matters more than it looks: `master` here is what every nf-core repo reads
its Renovate preset from, so an unreviewed push is live org-wide immediately.
Treat PRs as the convention even though nothing enforces it.

Closing that gap — require PRs on `master` for everyone including `core`, keep
`core` as the only team that can merge, and add a CODEOWNERS file — is tracked in
[nf-core/ops#215](https://github.com/nf-core/ops/issues/215).

## Re-deriving this

```bash
# team permissions on a repo
gh api repos/nf-core/ops/teams --jq '.[] | "\(.slug)\t\(.permission)"'

# who is on a team
gh api "orgs/nf-core/teams/core/members?per_page=100" --jq '.[].login'

# branch protection (404 = unprotected)
gh api repos/nf-core/ops/branches/main/protection

# rulesets, which can apply even when protection is absent
gh api repos/nf-core/.github/rulesets

# your own effective permission
gh api repos/nf-core/.github --jq .permissions
```
