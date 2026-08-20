# Renovate configuration

Dependency updates across nf-core are driven by a single shared Renovate preset.
This document explains where that preset lives, why it lives there, and what not
to do to it.

## Where things live

| What                     | Where                                                                                     |
| ------------------------ | ----------------------------------------------------------------------------------------- |
| The shared preset        | [`nf-core/.github`](https://github.com/nf-core/.github) → `renovate-config.json` (public) |
| Optional custom managers | `nf-core/.github` → `process_updaters.json5` (public, opt-in)                             |
| This repo's own config   | `.github/renovate.json5` — a one-line `extends` of the shared preset                      |
| Legacy copy              | `.github/renovate/` — superseded, kept only until every consumer migrates                 |

## Why the preset is not in this repo

It used to be, referenced as
`github>nf-core/ops//.github/renovate/default.json5`.

`nf-core/ops` is **private**. A Renovate preset has to be readable by every repo
that extends it, so once this repo went private the reference stopped resolving,
Renovate raised a config error, and dependency PRs stopped across the org — see
[nf-core/tools#4446](https://github.com/nf-core/tools/issues/4446).

The fix was to move the preset to the public `nf-core/.github` repo rather than
make this repo public. Beyond being public, that location is the one Renovate
probes by convention: it looks for `renovate-config.json` in an org's `.github`
repo during onboarding, so new nf-core repos inherit the preset with no PR.
Details in the [Renovate docs](https://docs.renovatebot.com/config-presets/#grouporganization-level-presets)
and the [`nf-core/.github` README](https://github.com/nf-core/.github#renovate-preset).

**Do not move the shared preset back into this repo, and do not add a preset
reference that points at `nf-core/ops`.** Any such reference resolves for
maintainers with access and 404s for everyone else, which is exactly the failure
above and is easy to miss locally.

## Consumers

Every repo below extends the shared preset. A breaking change to
`renovate-config.json` affects all of them at once:

`nf-core/ops`, `nf-core/tools`, `nf-core/modules`, `nf-core/test-datasets`,
`nf-core/website`, `nf-core/setup-nextflow`, `nf-core/setup-nf-test`, and
externally `nextflow-io/schemas`.

To re-derive that list rather than trusting it:

```bash
gh search code "nf-core/.github:renovate-config" --limit 50
```

## Changing the preset

Edits go through a PR on `nf-core/.github`. Two constraints:

- `renovate-config.json` must remain **strict JSON**. Auto-discovery only looks
  for the `.json` extension, so it cannot be renamed to `.json5`, which means no
  comments and no trailing commas.
- Renovate reads the preset from the default branch, so a merge is immediately
  live for every consumer. Test from a branch first:
  `github>nf-core/.github:renovate-config#my-branch`.

Validate before pushing. Two commands, because the validator checks the schema
but accepts JSON5 syntax in a `.json` file — it passes on comments and trailing
commas, which auto-discovery then rejects:

```bash
npx --package renovate renovate-config-validator renovate-config.json
python3 -c "import json; json.load(open('renovate-config.json'))"
```

This repo also runs `renovate-config-validator` as a pre-commit hook, so local
config files get the schema check automatically — but not the strict-JSON one.

## Verifying preset resolution

`renovate-config-validator` checks the schema — it does **not** fetch remote
presets, so it passes on a config whose preset 404s. That gap is what let the
original breakage through. To check that a preset actually resolves:

```bash
LOG_LEVEL=debug renovate --platform=local --dry-run=lookup 2>&1 | grep -i preset
```

Look for a `contents/renovate-config.json` fetch and the absence of
`Preset fetch error`.

One caveat: `--platform=local` cannot resolve `local>` references at all
("The platform you're using (local) does not support local presets"). Use the
equivalent `github>nf-core/.github:renovate-config` form when testing this way.
An unauthenticated `curl` is a cheaper check that a preset is publicly readable:

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  https://raw.githubusercontent.com/nf-core/.github/master/renovate-config.json
```

## Permissions

Merge rights and PR rights differ between the two repos; see
[`docs/github-permissions.md`](../github-permissions.md).
