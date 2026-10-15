# Seqera workspace access migration

This plan moves nf-core Seqera workspace participant access into Terraform while preserving current users' effective access and requiring a human decision for every grant change. It covers access to the existing shared workspace; it does not transfer ownership of the Seqera organization or workspace.

## Current facts and limits

- This repository had no Terraform state or backend at the checked-out upstream revision. Bootstrap of the remote S3 backend and AWS OIDC access is a separate prerequisite.
- Read-only Seqera connector queries on 2026-10-15 confirmed the existing `nf-core/AWSmegatests` production workspace and a separate `AWSmegatests-dev` workspace. Both report `SHARED` visibility. No workspace ID is committed; operators must confirm the production target in the protected workspace secret.
- The local CLI lacks `TOWER_ACCESS_TOKEN`. The authenticated connector exposes organization/workspace discovery but did not expose team, participant, or role-catalogue reads in its tool search. Current teams, memberships, direct grants, and custom-role availability therefore still require a private administrator inventory.
- The starting Terraform manifest is intentionally empty. It is a schema example, not an approved desired state. Applying it after team memberships have been imported can remove those team memberships.
- Existing Pulumi/AWSMegatests participant automation is historical context only. It used GitHub email discovery and role assignment logic; neither its identity data nor its policy is authoritative for this migration.
- Seqera's workspace docs state that participants have workspace access roles and that newly added participants default to Launch. Seqera also documents that direct and team-derived access combine using the higher privilege set. Therefore the access review must examine effective access across direct and team grants. Direct individual participants are intentionally outside this module's Terraform state.

`SHARED` visibility is a material policy decision: [Seqera documents that shared pipelines can be launched from other organization workspaces with their associated compute environment](https://docs.seqera.io/platform-enterprise/24.1/orgs-and-teams/workspace-management#use-shared-pipelines-from-a-private-workspace). Removing a team membership must not be represented as removing every route to a shared pipeline. Test this route during removal and read-only-role verification. Decide with the workspace owner whether shared pipelines remain a documented exception or whether workspace visibility must change under the separate workspace configuration ticket (#220). This access module does not change visibility or claim exclusive access control.

## Candidate discovery for manual review

Public nf-core sources can generate candidate lists for human review:

- The [nf-core governance page](https://nf-co.re/governance) publishes current core and maintainers rosters as GitHub profile links. Its core responsibilities include adding community members to the Seqera workspace. Use its current core roster as a candidate set for the `core` group, then obtain explicit approval and confirm current status.
- The [pipeline contributor guidance](https://nf-co.re/docs/contributing/contributor-types) defines an active pipeline maintainer as a current lead developer who regularly contributes and manages that pipeline. Inspect current `nextflow.config` manifests for pipelines in scope and use only entries designated `maintainer` as candidates for `pipeline-maintainers`; review whether each person is still active. Historical `author` and `contributor` entries do not on their own establish current launch/configuration need.
- The [core team task guide](https://nf-co.re/docs/community/governance/core-team) documents core responsibilities for the Seqera workspace and directs core to add main pipeline developers to relevant channels during onboarding. It can inform context, but a Slack/channel roster is not an access authorization source.
- `view` has no automatic nf-core roster source. A human workspace sponsor must propose each user and document the concrete read-only need.

Public pages may be stale and identify GitHub accounts, not Seqera identities. Keep candidate discovery read-only. The PR reviewer must make the actual membership decision; Terraform must not scrape these pages or infer permissions from GitHub team membership, a pipeline manifest, commits, or prior Seqera access. Use public handles in any public record. Match each approved handle to the Seqera organization `member_id` only through the private administrator-confirmed identity map described in [terraform/seqera-access/README.md](../terraform/seqera-access/README.md). Keep `member_id`, Seqera `user_id`, and workspace `participantId` distinct in the private inventory. Never commit or publish email addresses.

## Access matrix to verify

These are capability requirements, not a claim that a provider role has already passed live verification. The current implementation pins `seqeralabs/seqera` 0.42.0, uses Seqera organization teams, assigns the built-in workspace `admin` role to `core`, and defines custom workspace roles for `pipeline-maintainers` and `view`. The provider permission catalogue and effective permissions still need confirmation in the target organization before production apply.

| Group                  | Required behavior                                                                                              | Must not grant                                                                             |
| ---------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `core`                 | Administer workspace participant grants and assign participant roles; administer the needed workspace settings | Seqera organization ownership, organization membership, and custom role definition changes |
| `pipeline-maintainers` | Launch pipelines; add and edit Launchpad pipeline entries/configuration                                        | Launchpad removal, participant/role administration, or workspace deletion                  |
| `view`                 | Read workspace resources, pipeline definitions, and run details needed for observation                         | Launching runs, editing Launchpad/configuration, or changing participant roles             |

Seqera has built-in workspace roles and allows custom roles. The current implementation uses custom roles because provider issue [#237](https://github.com/seqeralabs/terraform-provider-seqera/issues/237) reports that assigning the built-in `view` role may yield launch permission on provider 0.41.0 with Seqera Enterprise 25.1. This report does not establish that provider 0.42.0 has the same defect. Its custom roles use permission names for pipeline and workflow read/write/execute plus selected resource reads, but those names and their correspondence to Launchpad editing must be validated against the live permission catalogue and tested. The configuration will fail its catalogue precondition if a configured permission is absent; this checks existence, not intended semantics. Do not treat a successful plan as proof of effective permissions. Confirm each role with user-scoped actions and retain results with the migration record. Custom roles also require the organization's `CUSTOM_ROLES` feature toggle. Workspace admins manage workspace participant grants; definition and update of custom roles remain Terraform/operator work at organization scope.

The Terraform implementation manages organization teams, their memberships, custom workspace roles, and team workspace participant grants. It does not manage direct individual participants or the workspace object. Seqera organization teams require approved users to be existing organization members; a separate human-controlled organization onboarding step is required for collaborators/non-members. The provider 0.42.0 `seqera_team_member` import requires `ORG_ID/TEAM_ID/EMAIL`, while ongoing configuration supports numeric organization `member_id`. Use the email only in the private one-time import command; after refresh, reconcile state with the private map from GitHub handle to organization `member_id`. Do not substitute Seqera `user_id` or workspace `participantId`. Never put emails in the public manifest or invent an import key.

## Phased migration

### 0. Agree on scope and bootstrap

1. Confirm the target Seqera organization and workspace from an authorized administrator. Record numeric IDs in protected configuration, not public files.
2. Bootstrap the remote S3 state bucket, encryption/versioning controls, and AWS OIDC role outside this module. Verify Terraform can initialize and acquire/release its backend lock. Keep bootstrap credentials out of the Seqera provider path.
3. Pin the provider version, Terraform version, and lock file. Verify participant import, custom role management, state refresh, role updates, and delete behavior using provider docs/source and safe test resources before touching existing access.
4. Keep the default apply gate disabled. Configure protected-environment reviewers and the approved CI plan/apply flow before enabling access changes.

### 1. Capture the baseline

1. An administrator with live access exports or records a point-in-time inventory of direct individual participants and their roles, organization teams and members, team workspace grants, and custom role permission definitions. For each managed role name, inventory every existing assignment across all organization workspaces, not just the target workspace. Record when and how the inventory was captured.
2. Verify that the inventory is complete through the Seqera UI/API and account for collaborators as well as organization members. Seqera documents that adding a username or email can create an organization membership and workspace participant, with separate seat limits and notifications; any required organization membership must be approved and handled outside this module.
3. Store raw inventory privately. Create the private lowercase GitHub handle to Seqera organization `member_id` mapping for proposed team memberships; resolve aliases and shared/duplicate accounts with the affected users and an administrator. Keep `member_id`, Seqera `user_id`, and workspace `participantId` as separately labeled fields. Keep the direct-participant list as a separate, unmanaged baseline.
4. Establish a recovery path: at least one authorized administrator outside the grant set can access the workspace and restore participant roles if the apply removes or downgrades access. Verify this path before import.

### 2. Import without changing access

1. Do not declare or import the externally owned workspace or direct individual participants. Record direct user grants for later operator-reviewed removal only after team-based replacements pass effective-access tests.
2. Import existing matching organization teams and team memberships. Import team workspace participant grants only when they correspond to the intended managed role for that team. Import pre-existing custom roles with the exact names managed here only after confirming their permissions exactly match the intended definition and every assignment belongs to the approved migration scope. If a role is used outside that scope, leave it unmanaged and choose a new, unused name for the managed role in a reviewed code change before applying; do not repurpose a shared role. Custom-role definitions are organization-wide, so changing one affects every workspace where it is assigned. Retain that assignment check for later permission changes; retain other roles and all direct participant grants in the private inventory pending an explicit decision.
3. Provider 0.42.0 imports use: team `{"org_id":ORG_ID,"team_id":TEAM_ID}`; team member `ORG_ID/TEAM_ID/EMAIL`; team workspace participant `ORG_ID/WORKSPACE_ID/team:TEAM_ID`; custom role `{"name":"ROLE_NAME","org_id":ORG_ID}`. Team-member import email must remain private and be used only for import; subsequent config uses the numeric organization `member_id`. See [provider-capabilities.md](../terraform/seqera-access/provider-capabilities.md).
4. Run refresh-only and normal plans. Confirm imported objects have no unintended changes. Review intentional creates of teams/custom roles/team workspace grants separately, since these can change effective access. Investigate every delete, role change, replacement, or unknown value.
5. Commit the manifest schema and imported baseline code only after both the imported-object diff and intentional additive plan have been reviewed. Keep private identity data out of the commit.

### 3. Review and approve desired membership

1. Build candidate sets from current public nf-core governance rosters and active pipeline manifest entries. Treat these as evidence to review, not a generated policy.
2. Have a named human reviewer explicitly approve each handle, group, and intended capability. A handle may appear in multiple groups when the reviewer records why each capability is needed; effective access is the union of team grants, so review the combined permissions.
3. Confirm each approved handle-to-organization-`member_id` mapping privately. Missing or ambiguous mappings block that identity's change.
4. Propose changes in a PR using data-only membership input where possible. Include rationale, candidate source and review date, and a privacy-safe summary. The PR does not contain user IDs, names, or emails.
5. Generate the plan using trusted base Terraform and scripts for data-only PRs. For code changes, require a trusted maintainer to inspect and run the plan through the approved operator route. Do not give credentials to untrusted PR code.

### 4. Add and verify before removing

The provider creates a workspace participant and updates its role in separate calls. For newly created teams, the Terraform dependency completes the intended grant before adding members. Prefer an empty-team grant pilot, verify the actual role, and then add approved memberships. A pre-existing populated team receiving a new workspace grant needs separate review of the temporary default-role window. A failed role update can leave a partial live grant that the recovery administrator must inspect and repair before retrying.

1. Apply additive grants first. Before approving the membership PR, run the protected manifest-only plan for its exact head SHA and inspect its sanitized summary. After merge, the plan environment approves a fresh plan for the event's exact commit SHA. A separate apply environment then requires reviewer approval after that plan summary is available.
2. Verify actual permissions as affected identities: core workspace participant administration and role assignment; pipeline maintainer launch and Launchpad pipeline entry/configuration add/edit; view resource/run read with launch and edit denied. Test direct and team-derived roles where present. Also verify custom-role definitions through the administrator/operator route; core workspace admin alone does not manage organization-level custom role definitions. Here, configuration means pipeline template/Launchpad configuration, not arbitrary workspace settings.
3. Record pass/fail results without storing private identity details in public artifacts. Resolve failures and provider issues before proceeding.
4. In a separate reviewed/manual change, remove obsolete direct user participants only after replacement team access or offboarding is confirmed. Inspect every removal and verify recovery-admin access remains. Direct participants are not represented in this Terraform plan.

### 5. Reconcile and operate

Review membership on a documented cadence and when public source rosters or pipeline maintainers change. Each review should compare a fresh live inventory, desired manifest, and Terraform state. Use a reviewed PR for each team membership or role update. Keep direct and team-derived access visible during review; a low direct role does not reduce higher access inherited from another grant. Direct user grants remain separately managed until deliberately retired.

## CI plan and apply contract

The repository's CI flow must preserve these boundaries:

- The pre-merge protected `workflow_dispatch` accepts a data-only `members.json` input and runs trusted main-revision Terraform and validation scripts. It records the exact PR head SHA and must not execute pull-request HCL, scripts, or actions with Seqera credentials. A human PR reviewer must inspect that run's sanitized plan summary before approving the PR; this is a review procedure, not an enforced GitHub required check.
- Terraform source or script changes require a trusted maintainer to produce and inspect a plan through the approved operator path.
- The default-branch workflow is path filtered and can plan only when its repository enable variable is explicitly on. The apply job waits for a separate protected-environment approval after the live merged-commit plan summary is available.
- The apply job regenerates the plan from the exact merged commit, compares the SHA-256 fingerprint of canonical private plan JSON to the reviewed plan job's fingerprint, then applies that job's local saved plan. Canonicalization excludes only Terraform's top-level `timestamp`; all other fields are included. It checks the job's captured `SEQERA_ACCESS_ENABLED` value immediately before apply. Turning the variable off prevents future jobs from starting; it does not stop a job that is already running, so cancel active runs in Actions for an immediate stop. If the fingerprint differs or the captured gate is off, it stops without applying and requires a fresh run and review. The raw plan and JSON remain on ephemeral runners.
- Keep `SEQERA_ACCESS_ENABLED` and `SEQERA_ACCESS_ALLOW_DELETIONS` false until the imported baseline and access changes have been reviewed. A plan containing deletion can be inspected while the deletion gate is off, but apply stops until the gate is explicitly enabled and the plan is reviewed again.
- Restrict both `seqera-access-plan` and `seqera-access-apply` environments to the `main` branch and configure required reviewers. The workflow dispatch ref check is defense in depth; the environment's branch rule prevents a modified workflow on another branch from receiving environment secrets.
- Configure repository branch protection to require code-owner approval, dismiss stale approvals, require approval of the latest push, and require the `validate` workflow check before merge. CODEOWNERS requests infrastructure-team review but does not enforce these requirements by itself. Protect CODEOWNERS and workflow changes under existing repository ownership rules; verify the settings in GitHub before enabling apply.
- CI artifacts and logs may contain only sanitized resource addresses, action types, and a concise result. Do not upload the raw plan, state, identity map, provider debug logs, or unfiltered output.
- Keep both repository gates off through bootstrap, baseline import, role verification, mapping, and no-op flow validation. Turning them on is a final activation step, not part of initial setup.

## Rollback and recovery

If a grant is missing or over-permissive, stop subsequent removals. Use the independent recovery administrator to restore access in Seqera, then update Terraform state/configuration to match that live state through a reviewed reconciliation. Do not use `terraform state rm`, resource deletion, or state replacement as a shortcut to conceal drift. If an apply fails partway, capture the sanitized run result, refresh against the platform, inspect effective roles, and prepare a new plan from current state before retrying.

## Completion gates

Migration is complete only when:

- Backend bootstrap, lock behavior, and CI identity are verified.
- A timestamped live baseline has been captured; existing in-scope teams and memberships are imported, while direct user participant grants remain documented outside Terraform.
- Imported objects have a reviewed no-unintended-change plan, and intentional team/role/workspace-grant resources have a separately reviewed additive plan.
- Public-source candidates were manually reviewed, and approved identities have private verified mappings.
- Managed custom-role names have a private organization-wide assignment inventory proving no out-of-scope assignments will be affected; existing shared definitions remain unchanged.
- Provider custom role definitions and participant role assignments pass effective, user-scoped permission tests.
- The recovery administrator and recovery procedure are confirmed.
- Protected plan review and saved-plan apply are exercised with no-op/data-only cases; raw secrets, identities, and plans never leave protected contexts.
- The access apply gate is enabled only after all above checks pass and a human approves the final baseline PR.

## Primary references

- [nf-core governance rosters and responsibilities](https://nf-co.re/governance)
- [nf-core pipeline contributor types](https://nf-co.re/docs/contributing/contributor-types)
- [nf-core core team procedures](https://nf-co.re/docs/community/governance/core-team)
- [Seqera workspace participant management](https://docs.seqera.io/platform-cloud/orgs-and-teams/workspace-management)
- [Seqera user roles and effective access](https://docs.seqera.io/platform-enterprise/orgs-and-teams/roles)
- [Seqera custom roles](https://docs.seqera.io/platform-cloud/orgs-and-teams/custom-roles)
- [Seqera Terraform provider](https://github.com/seqeralabs/terraform-provider-seqera)
