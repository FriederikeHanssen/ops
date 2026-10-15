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

run "known_handles_create_stable_memberships_and_roles" {
  command = plan

  variables {
    org_id                = "100"
    workspace_id          = "200"
    members_manifest_path = "tests/fixtures/valid-members.json"
    identity_map = {
      alice = "9001"
      bob   = "9002"
      carol = "9003"
    }
  }

  assert {
    condition     = toset(keys(seqera_team_member.managed)) == toset(["core/alice", "pipeline-maintainers/bob", "view/carol"])
    error_message = "Membership resource addresses must remain stable and keyed by team and GitHub handle."
  }

  assert {
    condition     = seqera_workspace_participant.managed["core"].role == "admin"
    error_message = "The core team must receive the workspace admin role."
  }

  assert {
    condition     = seqera_workspace_participant.managed["pipeline-maintainers"].role == seqera_custom_role.pipeline_maintainers.name
    error_message = "Pipeline maintainers must use the custom least-privilege role."
  }

  assert {
    condition     = contains(seqera_custom_role.pipeline_maintainers.permissions, "pipeline:write") && contains(seqera_custom_role.pipeline_maintainers.permissions, "workflow:execute") && contains(seqera_custom_role.pipeline_maintainers.permissions, "workspace_resources:read")
    error_message = "Pipeline maintainers need Launchpad create/configure, launch, and UI browse permissions."
  }

  assert {
    condition     = alltrue([for permission in seqera_custom_role.view.permissions : can(regex(":read$", permission))])
    error_message = "The view role must contain read-only permissions."
  }
}

run "unknown_manifest_handle_fails_closed" {
  command = plan

  variables {
    org_id                = "100"
    workspace_id          = "200"
    members_manifest_path = "tests/fixtures/unknown-handle.json"
    identity_map          = {}
  }

  expect_failures = [terraform_data.manifest_guard]
}

run "duplicate_numeric_alias_fails_closed" {
  command = plan

  variables {
    org_id                = "100"
    workspace_id          = "200"
    members_manifest_path = "tests/fixtures/duplicate-member.json"
    identity_map = {
      alice = "9001"
      alias = "9001"
    }
  }

  expect_failures = [terraform_data.manifest_guard]
}

run "non_numeric_member_id_fails_closed" {
  command = plan

  variables {
    org_id                = "100"
    workspace_id          = "200"
    members_manifest_path = "tests/fixtures/invalid-member-id.json"
    identity_map = {
      alice = "9e3"
    }
  }

  expect_failures = [terraform_data.manifest_guard]
}

run "missing_permission_catalogue_entry_fails_closed" {
  command = plan

  variables {
    org_id                = "100"
    workspace_id          = "200"
    members_manifest_path = "tests/fixtures/valid-members.json"
    identity_map = {
      alice = "9001"
      bob   = "9002"
      carol = "9003"
    }
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

run "duplicate_handle_in_team_fails_closed" {
  command = plan

  variables {
    org_id                = "100"
    workspace_id          = "200"
    members_manifest_path = "tests/fixtures/duplicate-handle-in-team.json"
    identity_map = {
      alice = "9001"
    }
  }

  expect_failures = [terraform_data.manifest_guard]
}

run "overlapping_teams_keep_explicit_membership_addresses" {
  command = plan

  variables {
    org_id                = "100"
    workspace_id          = "200"
    members_manifest_path = "tests/fixtures/overlapping-teams.json"
    identity_map = {
      alice = "9001"
    }
  }

  assert {
    condition     = toset(keys(seqera_team_member.managed)) == toset(["core/alice", "view/alice"])
    error_message = "Overlapping team assignments are allowed and retain distinct team/handle addresses."
  }
}
