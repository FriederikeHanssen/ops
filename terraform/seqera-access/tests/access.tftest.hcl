mock_provider "seqera" {
  mock_data "seqera_permissions" {
    defaults = {
      names = [
        "container:read",
        "compute_environment:read",
        "credentials:read",
        "label:read",
        "launch:read",
        "pipeline:read",
        "pipeline:write",
        "platform:read",
        "workflow:execute",
        "workflow:read",
        "workflow:write",
        "workspace:read",
        "workspace_resources:read",
      ]
    }
  }
}

run "teams_receive_the_intended_workspace_roles" {
  command = plan

  variables {
    org_id       = 100
    workspace_id = 200
  }

  assert {
    condition = alltrue([
      for name in [seqera_custom_role.pipeline_maintainers.name, seqera_custom_role.view.name] :
      can(regex("^[a-z][a-z0-9-]*$", name)) && length(name) <= 40
    ])
    error_message = "Custom role names must use lowercase slug identifiers, without spaces, and fit within 40 characters."
  }

  assert {
    condition     = toset(keys(seqera_teams.managed)) == toset(["pipeline-maintainers", "view"]) && seqera_teams.managed["view"].name == "viewers"
    error_message = "The module must manage only the pipeline-maintainers and viewers teams."
  }

  assert {
    condition     = !contains(keys(seqera_workspace_participant.managed), "core")
    error_message = "Existing core access must remain outside this Terraform scope."
  }

  assert {
    condition     = seqera_workspace_participant.managed["pipeline-maintainers"].role == seqera_custom_role.pipeline_maintainers.name && contains(seqera_custom_role.pipeline_maintainers.permissions, "pipeline:write") && contains(seqera_custom_role.pipeline_maintainers.permissions, "workflow:execute") && !contains(seqera_custom_role.pipeline_maintainers.permissions, "pipeline:delete")
    error_message = "Pipeline maintainers must receive the custom launch/configuration role without pipeline deletion."
  }

  assert {
    condition     = seqera_workspace_participant.managed["view"].role == seqera_custom_role.view.name && alltrue([for permission in seqera_custom_role.view.permissions : can(regex(":read$", permission))])
    error_message = "View must receive a read-only custom role."
  }
}

run "missing_catalogue_permission_fails_closed" {
  command = plan

  variables {
    org_id       = 100
    workspace_id = 200
  }

  override_data {
    target = data.seqera_permissions.catalogue
    values = {
      names = [
        "container:read",
        "compute_environment:read",
        "credentials:read",
        "label:read",
        "launch:read",
        "pipeline:read",
        "platform:read",
        "workflow:execute",
        "workflow:read",
        "workflow:write",
        "workspace:read",
        "workspace_resources:read",
      ]
    }
  }

  expect_failures = [seqera_custom_role.pipeline_maintainers]
}
