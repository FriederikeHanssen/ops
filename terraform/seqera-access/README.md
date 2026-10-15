# Seqera workspace roles and teams

This Terraform root creates two organization custom roles, three initially empty
teams, and a team grant for each team in one existing workspace. Team membership
is managed separately by administrators. This root does not manage the workspace
itself, add organization members, or manage direct user grants.

| Team                   | Workspace role                 | Intended access                                    |
| ---------------------- | ------------------------------ | -------------------------------------------------- |
| `core`                 | `admin`                        | Workspace administration                           |
| `pipeline-maintainers` | `nf-core Pipeline Maintainers` | Launch workflows and create or configure pipelines |
| `view`                 | `nf-core Read Only`            | Read workspace pipelines and workflow information  |

The two custom roles are organization-level Seqera roles, even though this
configuration grants them to teams in one workspace. Before adopting an
existing role name, check its permissions and assignments across every
organization workspace. Preserve shared roles and direct user grants; changing
or removing them is outside this root's scope. The organization must have the
custom roles entitlement enabled, and the configured permissions must exist in
its permission catalogue.

## Configuration

The module pins `seqeralabs/seqera` provider `0.42.0`. Provide the provider
token and target IDs through the environment:

```sh
export TOWER_ACCESS_TOKEN="..."
export TF_VAR_org_id="..."
export TF_VAR_workspace_id="..."
```

Terraform uses local state by default. For shared operation, configure an
appropriate remote backend separately. State contains organization and
workspace identifiers and access configuration; keep it private. Do not commit
tokens, state, plans, or other secret values.

## Plan and apply

Run these commands from `terraform/seqera-access`. Review the plan before applying:

```sh
terraform init
terraform plan -out=access.tfplan
terraform apply access.tfplan
```

To check the configuration without applying it:

```sh
terraform validate
terraform test
```

## Import existing objects

Import only resources that already exist and are in scope. Replace each
placeholder with an administrator-verified numeric ID. These are the import
formats for provider `0.42.0`:

```sh
terraform import 'seqera_teams.managed["core"]' '{"org_id":ORG_ID,"team_id":TEAM_ID}'
terraform import 'seqera_custom_role.view' '{"name":"nf-core Read Only","org_id":ORG_ID}'
terraform import 'seqera_workspace_participant.managed["core"]' 'ORG_ID/WORKSPACE_ID/team:TEAM_ID'
```

Importing a custom role adopts its organization-wide definition. Confirm its
permissions and all workspace assignments first. After import, run `terraform plan` and resolve any proposed change before applying.
