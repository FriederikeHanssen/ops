## Nextflow Best Practices

- Do NOT embed the configuration in nextflowConfig instead of using the snapshots field in seqerakit
- Please don't hard code the values that defeats the purpose of IaC

## Git Best Practices

- When pre-commit fails, don't try to amend the commit, because the commit didn't get made

- Optimized Command for LLM Diagnosis

  uv run pulumi up --non-interactive --verbose 2 --continue-on-error --diff --yes

  This command provides:
  - --non-interactive - No interactive prompts (LLM-friendly)
  - --verbose 2 - Detailed logging for diagnosis
  - --continue-on-error - Shows all errors, doesn't stop on first failure
  - --diff - Rich diff display for changes
  - --yes - Auto-approves (when needed)

## Agent skills

### Issue tracker

Issues live as GitHub issues in `nf-core/ops`, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one root `CONTEXT.md` plus `docs/adr/`. See `docs/agents/domain.md`.
