# Seqera Terraform access management

This root pins `seqeralabs/seqera` **0.42.0**, the latest stable version found during implementation (0.43.0-RC2 was prerelease). It requires Terraform 1.10 or later and uses a partial S3 backend; CI must supply the private bucket, key, region, and AWS OIDC role. The Seqera provider reads `TOWER_ACCESS_TOKEN` from the environment.

The public `members.json` contains GitHub handles only. Protected `TF_VAR_identity_map` maps each lowercase handle to the numeric Seqera organization `member_id` of an existing member. Do not substitute Seqera `user_id` or workspace `participantId`, which can also appear in inventory. The configuration manages three teams, team memberships, two custom workspace roles, and workspace team participants. It never creates organization memberships, so it cannot send organization invitations. Team members must already belong to the organization.

## Permission design

`core` receives the predefined workspace `admin` role. `pipeline-maintainers` receives a custom role with workspace and resource browse access, pipeline template creation/configuration (`pipeline:write`), and workflow launch (`workflow:write`, `workflow:execute`, and supporting read permissions). [Seqera's custom-role reference](https://docs.seqera.io/platform-cloud/orgs-and-teams/custom-roles) defines `pipeline:write` to add and edit workspace pipelines; Launchpad visibility also uses `platform:read` and `workspace_resources:read`. [Seqera's role reference](https://docs.seqera.io/platform-cloud/orgs-and-teams/roles) says viewers cannot modify or execute resources; `view` is therefore implemented as an explicit read-only custom role with the platform and workspace resource browse permissions needed by the UI. Custom roles require the organization's `CUSTOM_ROLES` feature toggle; the plan fails if any configured permission is absent from the live catalogue.

The built-in `view` role is intentionally avoided. Issue [#237](https://github.com/seqeralabs/terraform-provider-seqera/issues/237) records a concern observed with provider 0.41.0 and Seqera Enterprise 25.1; that report does not establish behavior in the target organization. Provider 0.42.0 [workspace participant source](https://github.com/seqeralabs/terraform-provider-seqera/blob/v0.42.0/internal/seqera/workspace_participant/resource.go) takes the role-update path for role names other than the literal `view`, which includes this module's custom role name. This source detail does not prove that the custom permissions work as intended. Runtime behavior still needs verification in the target organization/workspace before production apply.

## Import and first apply

The manifest is deliberately empty. Before the first apply, inventory existing teams, memberships, and team workspace participants, then import every existing object into the stable addresses below and reconcile the manifest. Terraform's normal plan on an unimported existing object would otherwise propose creating a duplicate or expanding access. Keep at least one Seqera organization owner and an independent recovery path outside this configuration. No `prevent_destroy` is used on memberships, so removing a handle from the manifest revokes that team membership.

Stable addresses:

- `seqera_teams.managed["core"]`, `seqera_teams.managed["pipeline-maintainers"]`, `seqera_teams.managed["view"]`
- `seqera_team_member.managed["<team-key>/<github-handle>"]`
- `seqera_workspace_participant.managed["<team-key>"]`
- `seqera_custom_role.pipeline_maintainers` and `seqera_custom_role.view`

Import formats documented by provider 0.42.0:

- Team: `{"org_id": ORG_ID, "team_id": TEAM_ID}`
- Team membership: provider 0.42.0 source accepts `ORG_ID/TEAM_ID/EMAIL` during import, then its read path fills numeric `member_id`. The import email is a one-time private migration input; the committed manifest remains handles and Terraform configuration remains numeric IDs.
- Workspace team participant: `ORG_ID/WORKSPACE_ID/team:TEAM_ID`
- Custom role: `{"name":"ROLE_NAME","org_id":ORG_ID}`

The team membership import implementation requires `ORG_ID/TEAM_ID/EMAIL`, even though Terraform configuration and subsequent state refresh support numeric `member_id`. For migration, use an email only in the private one-time `terraform import` command or a protected script, then let refresh populate `member_id` and plan against the handle-to-ID map. Do not put email addresses in the manifest or CI logs. The workspace team participant can be imported directly by numeric team ID.

Participant creation and role assignment are separate API calls in this provider. Membership resources therefore depend on the completed workspace team grants. For a new team, create and verify its grant while it is empty before admitting users. For an existing populated team without a workspace grant, the initial grant can temporarily inherit the platform default before its role update; handle that case in the explicitly authorized migration. If the update fails, inspect and repair the partial grant with the recovery administrator before retrying.

## Limits and validation

The [Seqera issue #237](https://github.com/seqeralabs/terraform-provider-seqera/issues/237) describes a `view` role concern on provider 0.41.0 with Seqera Enterprise 25.1. Provider 0.42.0 source shows the literal-role update behavior described above; no separate 0.42.0 community report is relied on here.

Validation for this change passed Terraform schema validation, seven mocked Terraform tests, 20 Python tests, actionlint, and the configured repository pre-commit hooks. These checks cover local configuration and test fixtures only. Read-only connector discovery confirmed the production/development megatest workspaces and their `SHARED` visibility. The local CLI has no `TOWER_ACCESS_TOKEN`, and the connector's available discovery tools did not include access-control inventory. No live team inventory, permission-catalogue query, production plan, or effective-permission check was performed. Do not apply until imports and live permission checks are complete.
