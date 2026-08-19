# Legacy — reference only

This directory is being rewritten in Terraform. Read it to learn what the
infrastructure does; do not invest in it.

- Don't fix bugs, refactor, or improve consistency here. Known defects are
  expected to die with the rewrite.
- New infrastructure goes in `terraform/`, not here.
- When a task needs a change in this directory, say so and ask before editing.

The stacks still hold live state, so the rewrite needs `terraform import` for
existing resources rather than a clean apply. Treat resource names, IDs and
`op://` references here as the source of truth for what to import.

`terraform/cost-reporting/` is the pattern to copy: S3 remote state with
`use_lockfile = true`, `.envrc` holding only `op://` references, and a tracked
`terraform.tfvars.example` beside an ignored `terraform.tfvars`.
