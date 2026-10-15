locals {
  manifest = jsondecode(file("${path.module}/${var.members_manifest_path}"))
  raw_team_handles = {
    core                 = local.manifest.teams.core
    pipeline-maintainers = local.manifest.teams["pipeline-maintainers"]
    view                 = local.manifest.teams.view
  }
  team_handles = {
    core                 = toset(local.manifest.teams.core)
    pipeline-maintainers = toset(local.manifest.teams["pipeline-maintainers"])
    view                 = toset(local.manifest.teams.view)
  }
  all_handles        = toset(flatten(values(local.team_handles)))
  missing_identities = setsubtract(local.all_handles, toset(keys(var.identity_map)))

  # Use explicit team/handle keys so adding a member does not move the other
  # memberships in Terraform state.
  memberships = {
    for item in flatten([
      for team_key, handles in local.team_handles : [
        for handle in handles : {
          key    = "${team_key}/${handle}"
          team   = team_key
          handle = handle
        }
      ]
    ]) : item.key => item
  }
}

resource "terraform_data" "manifest_guard" {
  input = local.all_handles

  lifecycle {
    precondition {
      condition     = length(local.missing_identities) == 0
      error_message = "Every handle in members.json must have an entry in the private TF_VAR_identity_map."
    }
    precondition {
      condition     = alltrue([for handles in values(local.raw_team_handles) : length(handles) == length(toset(handles))])
      error_message = "A GitHub handle may appear only once in each team list."
    }
    precondition {
      condition = alltrue([
        for handle in local.all_handles :
        can(regex("^[1-9][0-9]*$", lookup(var.identity_map, handle, ""))) &&
        can(tonumber(lookup(var.identity_map, handle, ""))) &&
        try(tonumber(lookup(var.identity_map, handle, "")), 0) > 0
      ])
      error_message = "Every identity_map value used by members.json must be a positive numeric Seqera member ID."
    }
    precondition {
      condition     = alltrue([for handle in local.all_handles : handle == lower(handle) && length(trimspace(handle)) > 0])
      error_message = "GitHub handles in members.json must be non-empty and lowercase so manifest and private mapping keys stay stable."
    }
    precondition {
      condition = length(toset([
        for handle in setintersection(local.all_handles, toset(keys(var.identity_map))) : var.identity_map[handle]
      ])) == length(setintersection(local.all_handles, toset(keys(var.identity_map))))
      error_message = "Each listed Seqera member ID may map to only one GitHub handle."
    }
  }
}

resource "seqera_teams" "managed" {
  for_each = local.team_handles

  name        = each.key
  org_id      = tonumber(var.org_id)
  description = "Managed access team: ${each.key}"
}

resource "seqera_team_member" "managed" {
  for_each = local.memberships

  org_id    = tonumber(var.org_id)
  team_id   = seqera_teams.managed[each.value.team].team_id
  member_id = try(tonumber(lookup(var.identity_map, each.value.handle, "")), 0)

  # The provider creates a workspace participant before updating its role.
  # Finish the intended team grant before adding users to a new team.
  depends_on = [terraform_data.manifest_guard, seqera_workspace_participant.managed]
}

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
  org_id = tonumber(var.org_id)
}

resource "seqera_custom_role" "pipeline_maintainers" {
  org_id      = tonumber(var.org_id)
  name        = "nf-core Pipeline Maintainers"
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
  org_id      = tonumber(var.org_id)
  name        = "nf-core Read Only"
  description = "Read-only access to workspace pipelines and workflow information."
  permissions = sort(tolist(local.view_permissions))

  lifecycle {
    precondition {
      condition     = alltrue([for permission in local.view_permissions : contains(data.seqera_permissions.catalogue.names, permission)])
      error_message = "The Seqera organization permission catalogue does not contain every configured view permission. Refusing to apply an incomplete role."
    }
  }
}

resource "seqera_workspace_participant" "managed" {
  for_each = local.team_handles

  org_id       = tonumber(var.org_id)
  workspace_id = tonumber(var.workspace_id)
  team_id      = seqera_teams.managed[each.key].team_id
  role = {
    core                 = "admin"
    pipeline-maintainers = seqera_custom_role.pipeline_maintainers.name
    view                 = seqera_custom_role.view.name
  }[each.key]
}
