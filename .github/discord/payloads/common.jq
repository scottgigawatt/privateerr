#
# Copyright 2025-2026 Scott Gigawatt
#
# SPDX-License-Identifier: Apache-2.0
#
# common.jq: Render bounded, factual Discord embeds without enabling mentions.
#
# Usage: Included by notification payload templates.
#

#
# Bound public metadata to preserve Discord field and aggregate embed limits.
#
def field($name; $value):
  {name: $name, value: ($value | if length > 300 then .[0:297] + "..." else . end), inline: false};

def image_fields:
  [field("📦 Image"; $image_name), field("📁 Repository"; $repository), field("🌿 Ref"; $ref)]
  + (if $workflow_name != "" then [field("⚙️ Workflow"; $workflow_name)] else [] end)
  + (if $actor != "" then [field("👤 Triggered by"; $actor)] else [] end)
  + (if $platforms != "" then [field("🧱 Platforms"; $platforms)] else [] end)
  + (if $notification_type == "image-start" then
      [field("📦 GHCR image"; $ghcr_image)]
      + (if $dockerhub_image != "" then [field("🐳 Docker Hub image"; $dockerhub_image)] else [] end)
    else
      [field("📦 GHCR publication"; ($publication_status | if . == "" then "unconfirmed" else . end))]
      + (if $dockerhub_url != "unavailable" then [field("🐳 Docker Hub mirror"; ($mirror_status | if . == "" then "unconfirmed" else . end))] else [] end)
      + (if $publication_status == "success" and $digest != "unconfirmed" then [field("🏷️ Published tags"; $tags), field("🧾 Digest"; $digest)] else [] end)
      + (if $ghcr_url != "unavailable" then [field("📦 GHCR"; $ghcr_url)] else [] end)
      + (if $dockerhub_url != "unavailable" then [field("🐳 Docker Hub"; $dockerhub_url)] else [] end)
    end);

def docs_fields:
  [field("📁 Repository"; $repository), field("🌿 Ref"; $ref)]
  + (if $workflow_name != "" then [field("⚙️ Workflow"; $workflow_name)] else [] end)
  + (if $actor != "" then [field("👤 Triggered by"; $actor)] else [] end)
  + (if $notification_type == "docs-verdict" then
      [field("🛠️ Documentation build"; $build_status), field("🚀 Pages deployment"; $deploy_status)]
    else [] end)
  + (if $site_url != "" and $site_url != "unavailable" then [field("📚 Documentation site"; $site_url)] else [] end);

def fact:
  ($notification.subject // $image_name) as $subject
  | if $notification_type == "image-start" then
      "The " + $subject + " image pipeline has started."
    elif $notification_type == "docs-start" then
      "The " + $subject + " documentation update has started."
    elif $notification_type == "docs-verdict" then
      if $outcome == "success" then "The " + $subject + " documentation was published to GitHub Pages."
      elif $outcome == "cancelled" then "The " + $subject + " documentation update was cancelled."
      elif $outcome == "failure" then "The " + $subject + " documentation update failed during " + ($failure_stage | ascii_downcase) + "."
      elif $outcome == "skipped" then "The " + $subject + " documentation update was skipped."
      elif $outcome == "neutral" then "The " + $subject + " documentation update ended without a success or failure conclusion."
      else "The " + $subject + " documentation update needs attention. Review the build and deployment results." end
    elif $outcome == "success" then
      "The " + $subject + " image was published and its required publication checks passed."
    elif $outcome == "cancelled" then "The " + $subject + " image pipeline was cancelled."
    elif $outcome == "failure" then "The " + $subject + " image pipeline failed."
    elif $outcome == "skipped" then "The " + $subject + " image pipeline was skipped."
    elif $outcome == "neutral" then "The " + $subject + " image pipeline ended without a success or failure conclusion."
    else "The " + $subject + " image pipeline needs attention; its result is not confirmed as successful." end
  | . + (if $notification_type == "image-verdict" and $outcome != "success" and $publication_status == "success" then
      " GHCR publication completed before the pipeline stopped; check the remaining stages before using the image."
    else "" end);

def render:
  {
    username: $notification.username,
    allowed_mentions: {parse: []},
    embeds: [{
      title: $notification.title,
      description: ((fact + " " + $notification.message) | .[0:1000]),
      url: $url,
      color: $notification.color,
      fields: ((if $notification_type | startswith("docs-") then docs_fields else image_fields end)
        + (if $failure_stage != "" and $outcome != "start" and $outcome != "success" then [field("⚠️ Stage needing attention"; $failure_stage)] else [] end)
        + [field("🔗 View run"; $url)]),
      footer: {text: $notification.footer},
      timestamp: now | todate
    }]
  };
