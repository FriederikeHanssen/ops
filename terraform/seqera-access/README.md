# nf-core Seqera workspace access

This directory manages three Seqera organization teams, each team's membership, the team's workspace participant grant, and two custom workspace roles. It does not manage the workspace object or direct user participants. It does not decide who belongs in each access group: an explicitly reviewed manifest records those decisions.

## Access model

The manifest has three semantic groups. Terraform implements them as Seqera organization teams and workspace team participants; individuals are added to teams by their organization `member_id` from the private map. This is distinct from Seqera `user_id` and workspace `participantId`, which may also appear in an inventory. `core` uses the built-in workspace admin role. The other two groups use custom roles because provider issue [#237](https://github.com/seqeralabs/terraform-provider-seqera/issues/237) records a `view` role concern on provider 0.41.0 with Seqera Enterprise 25.1. This does not establish behavior in the target organization. Provider 0.42.0 source takes a separate role-update path for custom role names. The custom-role permission names and actual behavior still require validation in the target organization before production apply; the table describes intended access only.

| Manifest group         | Intended access                                                                                  | Membership decision                                                                |
| ---------------------- | ------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------- |
| `core`                 | Workspace administration, including workspace participant grants and assigning participant roles | Manually approved current nf-core core team members                                |
| `pipeline-maintainers` | Launch pipelines, add/edit Launchpad entries, and change the intended pipeline configuration     | Manually approved active pipeline maintainers                                      |
| `view`                 | Read-only access to workspace resources and runs                                                 | Manually approved users who need visibility without launch or configuration rights |

The initial manifest is deliberately empty:

```json
{
  "teams": {
    "core": [],
    "pipeline-maintainers": [],
    "view": []
  }
}
```

An empty manifest is a starting schema, not an approved access policy. Before the first apply, inventory direct workspace participants, existing Seqera teams, team memberships, workspace team grants, and custom roles. Import only existing objects that this module manages (teams, memberships, team workspace grants, and matching custom roles). Direct user participant grants remain outside this Terraform state and must be recorded separately. Do not remove them until replacement team-based access has been applied and verified. An empty team list can remove imported team memberships if applied after import.

To propose an approved membership change, edit only the public manifest with lowercase GitHub handles:

```json
{
  "teams": {
    "core": ["example-core-handle"],
    "pipeline-maintainers": ["example-pipeline-maintainer"],
    "view": ["example-viewer"]
  }
}
```

In the protected identity map, each handle maps to the numeric ID of an existing Seqera organization member. Use dummy IDs only in local examples; never commit a real map:

```json
{
  "example-core-handle": "12345",
  "example-pipeline-maintainer": "23456",
  "example-viewer": "34567"
}
```

These dummy values represent Seqera organization `member_id` values, not `user_id` or workspace `participantId` values.

The module does not create organization memberships or send invitations. A user who is not already an organization member must be added by an authorized administrator through the separately approved organization onboarding process, then mapped privately.

### Identity data and privacy

The committed manifest identifies people by lowercase GitHub handle. A private identity map translates each handle to the numeric Seqera organization `member_id` string required by the provider. Do not substitute `user_id` or workspace `participantId` from an inventory. Keep the map in a protected secret store or an ignored local file; do not commit names, email addresses, Seqera account emails, invite links, or IDs. Do not infer Seqera identities from public GitHub email data.

The mapping must be confirmed by a workspace administrator against the Seqera account and recorded in the private source of truth. Public nf-core pages can help identify candidates for manual review, but they do not establish Seqera identity or authorize access. Missing, ambiguous, or duplicate mappings block changes for that identity.

The current validator allows a handle in multiple access teams. Seqera combines those grants, so reviewers must assess the combined effective permissions and approve the full set of capabilities for each person.

## Repository and state

Pin a reviewed version of the Seqera Terraform provider in the root module. The provider is in public preview, so review its changelog and resource behavior before upgrades. Keep the Seqera access token in `TOWER_ACCESS_TOKEN` supplied by the CI secret mechanism; never put it in Terraform files, plans, artifacts, or logs.

The remote backend is an S3 backend with native lock-file support. The state bucket, key, AWS region, and AWS OIDC role are supplied by repository variables. Bootstrap the bucket, encryption/versioning policy, and GitHub OIDC role outside this module; ensure the role is restricted to this repository and the approved workflow/environment. Verify backend initialization and lock acquisition before Terraform initialization against Seqera. This repository had no Terraform backend before this migration, so do not assume one exists or create it as a side effect of the first access apply.

Terraform state contains Seqera identity and access metadata and must be treated as sensitive. Restrict state bucket and plan access to the minimum operator set. Never upload raw plans, state snapshots, provider debug output, or unfiltered Terraform logs as CI artifacts.

## Existing access inventory and import

The workspace itself and direct user participant grants are outside this module. Start with a read-only inventory from an authorized workspace administrator, including direct participant `participantId`/`user_id`/role fields when available, organization team IDs and membership `member_id` values, team workspace grants, and custom-role definitions/permissions. Capture it privately; do not add raw inventory to the repository.

Custom-role definitions are organization-wide, even though this root grants access to one workspace. Before importing an existing managed role name, confirm its permissions already match this configuration and inventory its assignments in every organization workspace. Do not adopt or change a role used outside the approved migration scope. Choose a new, unused managed role name through a reviewed code change instead, leaving the existing shared definition intact. Repeat the assignment-scope check before later permission changes. [Seqera role scope](https://docs.seqera.io/platform-api/info/roles-info).

Then:

1. Confirm organization and workspace IDs from protected configuration and the Seqera UI/API. The workspace is externally owned and is not declared as a Terraform resource.
2. Match proposed team members to verified Seqera organization `member_id` values and lowercase GitHub handles in the private identity map. Keep each organization's `member_id`, Seqera `user_id`, and workspace `participantId` distinct when recording inventory. Resolve ambiguous and unmapped identities manually. Record existing direct participants separately; do not import them into this module.
3. Declare and import existing resources this module manages, following the exact provider 0.42.0 formats below. For team-member imports, the provider accepts email only; supply that email privately at the one-time import command, never in Git. After import/read, reconcile Terraform configuration to organization `member_id` and verify a clean plan.
4. Confirm imported objects are represented without additional changes. Then review intentional planned creation of the managed custom roles, teams, and team workspace grants. Do not treat these expected adds as already applied or as a no-change baseline.
5. Only after imports and the additive plan are reviewed, propose membership changes in a reviewed PR. Keep direct grants in place until replacement team access passes effective-permission checks; remove them later through a separate reviewed/manual change.

The implementation pins `seqeralabs/seqera` 0.42.0. Stable Terraform addresses and import formats:

```sh
terraform import 'seqera_teams.managed["core"]' '{"org_id":ORG_ID,"team_id":TEAM_ID}'
terraform import 'seqera_team_member.managed["core/GITHUB_HANDLE"]' 'ORG_ID/TEAM_ID/EMAIL'
terraform import 'seqera_workspace_participant.managed["core"]' 'ORG_ID/WORKSPACE_ID/team:TEAM_ID'
terraform import 'seqera_custom_role.view' '{"name":"nf-core Read Only","org_id":ORG_ID}'
```

Replace placeholders with verified values. The email in the team-member import argument is a provider limitation: use it only in the protected terminal/session that performs import. Once state refresh reads the organization `member_id`, Terraform config continues to use the private numeric ID map. See [provider-capabilities.md](provider-capabilities.md) for every managed address and caveat. [Provider workspace documentation](https://registry.terraform.io/providers/seqeralabs/seqera/0.42.0/docs/resources/workspace) · [Provider resource index](https://registry.terraform.io/providers/seqeralabs/seqera/0.42.0/docs)

Validate a proposed manifest and local Terraform schema without connecting to the live backend:

```sh
python terraform/seqera-access/scripts/validate_manifest.py
terraform -chdir=terraform/seqera-access init -backend=false -lockfile=readonly
terraform -chdir=terraform/seqera-access validate
```

## Reviews and applies

The PR workflow has two modes, depending on who can safely execute it:

- A protected, pre-merge `workflow_dispatch` path accepts only a reviewable, data-only `members.json`. It checks out the trusted workflow revision, fetches that file from the exact PR head SHA, validates the manifest and private identity map, and produces a sanitized plan summary. It must not execute HCL, shell, provider, or workflow code from the pull request, and must not expose Seqera credentials to pull-request code.
- A change to Terraform code or scripts requires a trusted maintainer to run the plan locally or through the protected operator path, review the complete plan, and attach a sanitized summary to the PR. Untrusted PR changes never receive provider credentials.

After merge to the protected default branch, the path-filtered workflow runs only when `SEQERA_ACCESS_ENABLED` is explicitly `true`. Its `seqera-access-plan` environment protects credentialed planning. The workflow checks out the exact push SHA, validates the manifest before obtaining cloud credentials, and exposes only action/address summaries plus the custom-role name and permission delta. A separate `seqera-access-apply` environment requires reviewer approval after that summary is available. The apply job regenerates the plan and compares the SHA-256 fingerprint of canonical private plan JSON with the reviewed plan job. Canonicalization ignores only Terraform's top-level `timestamp`; every other field remains in the fingerprint. Apply uses its local saved plan only when the fingerprint matches and checks the job's captured `SEQERA_ACCESS_ENABLED` value immediately before applying. Turning the variable off prevents future jobs from starting; it does not stop a job that is already running, so cancel active runs in Actions for an immediate stop. If state or planned values differ, or the captured gate is off, it stops without applying; rerun for a fresh plan and review.

Configure both environments to allow deployments from `main` only and require reviewers. The environment branch restrictions are essential for `workflow_dispatch`: the run uses the workflow definition from its selected ref. Keep `SEQERA_ACCESS_ENABLED` and `SEQERA_ACCESS_ALLOW_DELETIONS` false until imports, identity mapping, role verification, inventory reconciliation, and recovery access are complete. A deletion is summarized but cannot apply while the deletion gate is false; enable it only after review, then rerun through both approvals.

The repository's [CODEOWNERS](../../.github/CODEOWNERS) file requests infrastructure-owner reviews for this path; it does not enforce them by itself. Configure branch protection/rulesets to require code-owner approval, dismiss stale approvals, require approval of the latest push, and require the `validate` workflow check before merge. Protect changes to the workflow and CODEOWNERS file under the repository's existing catch-all ownership rule. These settings must be verified in GitHub before apply is enabled; this documentation does not change repository visibility or claim that branch rules are already active.

Set these repository variables: `SEQERA_ACCESS_ENABLED` (initially `false`), `SEQERA_ACCESS_ALLOW_DELETIONS` (initially `false`), `SEQERA_STATE_BUCKET`, `SEQERA_STATE_KEY`, `SEQERA_STATE_REGION`, and `SEQERA_AWS_ROLE_TO_ASSUME`. Keep the enable gate at repository scope because the workflow checks it before starting the protected environment job and again, using the job's captured value, just before apply. Disabling the variable blocks future jobs; cancel already-running jobs in Actions to stop them immediately. Configure the same environment secrets in both `seqera-access-plan` and `seqera-access-apply`: `SEQERA_ORG_ID`, `SEQERA_WORKSPACE_ID`, `SEQERA_ACCESS_TOKEN`, and `SEQERA_IDENTITY_MAP`. The identity map is a JSON object from lowercase GitHub handles to Seqera organization `member_id` values; keep it private.

| Scope                       | Name                            | Initial/value guidance                                                                         |
| --------------------------- | ------------------------------- | ---------------------------------------------------------------------------------------------- |
| Repository variable         | `SEQERA_ACCESS_ENABLED`         | `false`; only turn on after all completion gates pass                                          |
| Repository variable         | `SEQERA_ACCESS_ALLOW_DELETIONS` | `false`; enable only for a reviewed plan that intentionally removes team memberships or grants |
| Repository variable         | `SEQERA_STATE_BUCKET`           | Pre-created private S3 backend bucket                                                          |
| Repository variable         | `SEQERA_STATE_KEY`              | Dedicated key for this Terraform root                                                          |
| Repository variable         | `SEQERA_STATE_REGION`           | Region containing the backend bucket                                                           |
| Repository variable         | `SEQERA_AWS_ROLE_TO_ASSUME`     | OIDC role limited to this repository and protected environments                                |
| Secret in both environments | `SEQERA_ORG_ID`                 | Numeric organization ID                                                                        |
| Secret in both environments | `SEQERA_WORKSPACE_ID`           | Numeric workspace ID                                                                           |
| Secret in both environments | `SEQERA_ACCESS_TOKEN`           | Seqera PAT held in `TOWER_ACCESS_TOKEN` only at runtime                                        |
| Secret in both environments | `SEQERA_IDENTITY_MAP`           | Private JSON map from lowercase handle to organization `member_id`                             |

Create `seqera-access-plan` and `seqera-access-apply` environments, set both to allow `main` deployments only, and require designated reviewers. The S3 bucket and OIDC role are external bootstrap resources and are not managed by this Terraform root.

CI may publish only a sanitized list of changed Terraform addresses and action types plus a concise success/failure result. It must not publish raw plans, values, identity mapping, state, or unfiltered logs.

## Change procedure

For each access change:

1. Review the proposed GitHub-handle membership change manually. Do not treat nf-core team membership, pipeline manifests, an issue comment, or the current Seqera inventory as automatic authorization.
2. Resolve each handle to a verified numeric Seqera ID using the private map. Record the approver and rationale in the PR without exposing private identity data.
3. Add grants first. Inspect the full plan, checking role IDs and permissions, the named users, and that existing access remains intact. Apply through the protected flow.
4. Verify effective access as each affected user, or with an administrator observing user-scoped checks: core can administer workspace participants; pipeline maintainers can launch a pipeline, add and edit Launchpad entries, and change the intended configuration; view users can inspect resources and runs but cannot launch or edit. Include tests for direct grants and team-derived grants where applicable because Seqera applies the higher effective role when a user has both.
5. Remove obsolete grants only in a later reviewed change after replacement access is verified. Validate the removal plan for every affected user; keep at least one independent recovery administrator throughout.

Never combine first-time grants, uncertain identity resolution, and broad grant removal into one apply. Stop if the plan contains an unreviewed user, a role escalation, an unexpected replacement/deletion, or a change to workspace resources outside the access scope.

## Access gates

Terraform apply must remain disabled until all of these conditions are met:

- The remote backend and AWS OIDC role are bootstrapped and tested independently.
- The exact provider version and participant/custom-role support are verified, including the observed role behavior and any known provider defects.
- An administrator has captured a current live access inventory. Connector discovery confirmed production and development megatest workspaces, both `SHARED`; teams, memberships, direct grants, and roles remain unverified. Review shared-pipeline access through other organization workspaces as a possible removal exception with the workspace owner.
- Every in-scope existing team and membership is represented in Terraform state; direct user grants are recorded separately, and no unreviewed destructive diff remains.
- The private handle-to-organization-`member_id` map is complete for proposed members and stored outside Git.
- A recovery administrator outside the changing grant set has confirmed access and can restore a failed change.
- The protected environment, reviewers, apply enable variable, saved-plan behavior, and sanitized reporting are configured and exercised with no-op or data-only changes.
- A human reviewer has explicitly approved each proposed membership and role assignment.

See [the migration plan](../../docs/seqera-access-migration.md) for the discovery sources, migration phases, and completion criteria.

## References

- [Seqera workspace management](https://docs.seqera.io/platform-cloud/orgs-and-teams/workspace-management) describes workspace participants, default Launch access, and role changes.
- [Seqera user roles](https://docs.seqera.io/platform-enterprise/orgs-and-teams/roles) describes effective access where direct and team-assigned roles overlap.
- [Seqera custom roles](https://docs.seqera.io/platform-cloud/orgs-and-teams/custom-roles) documents permission-level definitions for custom roles.
- [nf-core teams](https://nf-co.re/docs/community/governance/teams) describes the core and maintainers teams.
- [nf-core pipeline contributor types](https://nf-co.re/docs/contributing/contributor-types) defines current pipeline maintainership.
- [nf-core core team tasks](https://nf-co.re/docs/community/governance/core-team) documents core's administrative responsibilities.
