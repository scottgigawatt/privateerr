#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# check-image-tags.awk: Validate every Docker metadata-action tag block against
#                       the shared image publication policy.
#
# Usage: awk -v latest_rule=<rule> -v edge_rule=<rule> -v sha_rule=<rule> \
#            -v version_rule=<rule> -v minor_rule=<rule> -v major_rule=<rule> \
#            -f test/policy/awk/check-image-tags.awk <workflow>
#

#
# reset_block: Clear counters before validating one metadata-action block.
#
# Parameters: None.
#
# Returns: Resets block-local counters and returns no value.
#
function reset_block() {
  latest_count  = 0
  edge_count    = 0
  sha_count     = 0
  version_count = 0
  minor_count   = 0
  major_count   = 0
  type_count    = 0
  unsafe_count  = 0
}

#
# require_single_rule: Require exactly one canonical rule in the current block.
#
# Parameters: rule_count  - Number of matching rules in the current block.
#             description - Human-readable rule description for diagnostics.
#
# Returns: Records a validation failure when the count is not exactly one.
#
function require_single_rule(rule_count, description) {

  # Report missing and duplicate canonical rules with the same clear message.
  if (rule_count != 1) {
    printf "Metadata block %d must contain exactly one %s rule; found %d.\n", \
      block_count, description, rule_count > "/dev/stderr"
    failed = 1
  }
}

#
# validate_block: Apply the complete shared tag policy to the current block.
#
# Parameters: None.
#
# Returns: Records every rule-count or noncanonical-rule validation failure.
#
function validate_block() {
  require_single_rule(latest_count, "stable latest")
  require_single_rule(edge_count, "main edge")
  require_single_rule(sha_count, "commit SHA")
  require_single_rule(version_count, "exact semantic version")
  require_single_rule(minor_count, "stable minor alias")
  require_single_rule(major_count, "stable major alias")

  # Require the five canonical type rules in addition to latest=auto flavoring.
  if (type_count != 5) {
    printf "Metadata block %d contains %d tag rules; expected 5 canonical rules.\n", \
      block_count, type_count > "/dev/stderr"
    failed = 1
  }

  # Reject alternate latest, edge, and tag expressions that bypass the policy.
  if (unsafe_count != 0) {
    printf "Metadata block %d contains a noncanonical latest, edge, or tag rule.\n", \
      block_count > "/dev/stderr"
    failed = 1
  }
}

#
# classify_type_rule: Count one canonical tag rule or mark it noncanonical.
#
# Parameters: rule - Normalized metadata-action type rule.
#
# Returns: Updates the matching counter and returns no value.
#
function classify_type_rule(rule) {

  # Count the main-branch edge channel.
  if (rule == edge_rule) {
    edge_count++
    return
  }

  # Count the immutable commit SHA channel.
  if (rule == sha_rule) {
    sha_count++
    return
  }

  # Count the exact semantic-version release channel.
  if (rule == version_rule) {
    version_count++
    return
  }

  # Count the stable minor release alias.
  if (rule == minor_rule) {
    minor_count++
    return
  }

  # Count the guarded stable major release alias.
  if (rule == major_rule) {
    major_count++
    return
  }

  unsafe_count++
}

#
# Normalize each workflow line and classify rules within metadata-action blocks.
#
{
  workflow_rule = $0

  sub(/^[[:space:]]*/, "", workflow_rule)
  sub(/[[:space:]]*$/, "", workflow_rule)

  # Start a new independent validation block at each metadata-action step.
  if (workflow_rule ~ /^uses: docker\/metadata-action@/) {

    # Validate a preceding block when consecutive metadata steps are encountered.
    if (in_metadata_block) {
      validate_block()
    }

    block_count++
    in_metadata_block = 1

    reset_block()
    next
  }

  # Close the current block when the next workflow step begins.
  if (in_metadata_block && workflow_rule ~ /^- (name|uses|run):/) {
    validate_block()
    in_metadata_block = 0
  }

  # Ignore workflow lines outside a Docker metadata-action step.
  if (!in_metadata_block) {
    next
  }

  # Count the canonical latest flavor and flag alternate latest expressions.
  if (workflow_rule == latest_rule) {
    latest_count++
  }

  # Flag any alternate latest expression without double-counting latest=auto.
  if (workflow_rule ~ /^latest=/ && workflow_rule != latest_rule) {
    unsafe_count++
  }

  # Count canonical tag types and reject every unrecognized type expression.
  if (workflow_rule ~ /^type=/) {
    type_count++
    classify_type_rule(workflow_rule)
  }

  # Reject the older default-branch expression wherever it appears.
  if (workflow_rule ~ /is_default_branch/) {
    unsafe_count++
  }
}

#
# Validate a final open block and propagate the aggregate policy result.
#
END {

  # Validate a metadata block that reaches the end of the workflow file.
  if (in_metadata_block) {
    validate_block()
  }

  # Require the workflow to publish at least one image metadata block.
  if (block_count == 0) {
    print "No docker/metadata-action blocks found." > "/dev/stderr"
    failed = 1
  }

  # Return a failing status after all useful diagnostics have been printed.
  if (failed) {
    exit 1
  }
}
