locals {
  pipeline_permissions = toset([
    "container:read",
    "launch:read",
    "pipeline:read",
    "pipeline:write",
    "platform:read",
    "workflow:read",
    "workflow:execute",
    "workflow:write",
    "compute_environment:read",
    "credentials:read",
    "label:read",
    "workspace:read",
    "workspace_resources:read",
  ])
  view_permissions = toset([
    "container:read",
    "pipeline:read",
    "platform:read",
    "workflow:read",
    "compute_environment:read",
    "credentials:read",
    "label:read",
    "workspace:read",
    "workspace_resources:read",
  ])
}

data "seqera_permissions" "catalogue" {
  org_id = var.org_id
}

resource "seqera_custom_role" "pipeline_maintainers" {
  org_id      = var.org_id
  name        = "nf-core-pipeline-maintainers"
  description = "Create and configure Launchpad pipeline entries and launch workflows."
  permissions = sort(tolist(local.pipeline_permissions))

  lifecycle {
    precondition {
      condition     = alltrue([for permission in local.pipeline_permissions : contains(data.seqera_permissions.catalogue.names, permission)])
      error_message = "The Seqera organization permission catalogue does not contain every configured pipeline-maintainer permission. Refusing to apply an incomplete role."
    }
  }
}

resource "seqera_custom_role" "view" {
  org_id      = var.org_id
  name        = "nf-core-read-only"
  description = "Read-only access to workspace pipelines and workflow information."
  permissions = sort(tolist(local.view_permissions))

  lifecycle {
    precondition {
      condition     = alltrue([for permission in local.view_permissions : contains(data.seqera_permissions.catalogue.names, permission)])
      error_message = "The Seqera organization permission catalogue does not contain every configured view permission. Refusing to apply an incomplete role."
    }
  }
}

locals {
  team_roles = {
    core                 = "admin"
    pipeline-maintainers = seqera_custom_role.pipeline_maintainers.name
    view                 = seqera_custom_role.view.name
  }
}

resource "seqera_teams" "managed" {
  for_each = local.team_roles

  name        = each.key == "view" ? "viewers" : each.key
  org_id      = var.org_id
  description = "Managed access team: ${each.key}"
}

resource "seqera_workspace_participant" "managed" {
  for_each = local.team_roles

  org_id       = var.org_id
  workspace_id = var.workspace_id
  team_id      = seqera_teams.managed[each.key].team_id
  role         = each.value
}
