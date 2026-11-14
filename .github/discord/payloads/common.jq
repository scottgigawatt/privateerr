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
# Bound raw text before adding Markdown so links and code spans stay complete.
#
def plain($limit):
  gsub("[\u0000-\u001f\u007f]"; " ")
  | if length > $limit then .[0:($limit - 3)] + "..." else . end;

def text($limit):
  plain($limit) | split("") | map(
    if . == "\\" or . == "`" or . == "*" or . == "_" or . == "[" or . == "]"
      or . == "(" or . == ")" or . == "<" or . == ">" or . == "|" or . == "~"
    then "\\" + . else . end) | join("");

def code($limit):
  "`" + (plain($limit) | gsub("`"; "'")) + "`";

def field($name; $value; $inline):
  {name: $name, value: $value, inline: $inline};

#
# Only link validated identifiers and complete HTTPS destinations.
#
def safe_url:
  length <= 240 and test("^https://[A-Za-z0-9][A-Za-z0-9._~:/?#@!$&'*+,;=%-]*$");

def link($label; $target):
  if $target | safe_url then "[" + $label + "](" + $target + ")" else "" end;

def repository_text:
  if $repository | test("^[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9_.-]{1,100}$") then
    link(($repository | split("/") | last | text(100)); "https://github.com/" + $repository)
  else $repository | text(120) end;

def actor_text:
  if $actor | test("^[A-Za-z0-9][A-Za-z0-9-]{0,38}$") then
    link(($actor | text(80)); "https://github.com/" + ($actor | @uri))
  else $actor | text(80) end;

def context_fields:
  [field("📋 Build context";
    (["**Repo: 📁** " + repository_text, "**Ref: 🌿** " + ($ref | code(120))]
      + (if $actor != "" then ["**User: 👤** " + actor_text] else [] end) | join("\n")); true)];

def status_text:
  . as $status
  | ({success: "✅ success", failure: "❌ failure", skipped: "⏭️ skipped",
      cancelled: "⏹️ cancelled", neutral: "ℹ️ neutral", warning: "⚠️ warning",
      action_required: "⚠️ action required", unconfirmed: "⚠️ unconfirmed"}[$status]
    // ("⚠️ " + (if $status == "" then "unconfirmed" else $status | text(60) end)));

#
# Keep complete list items within a shared budget rather than cutting Markdown.
#
def code_list($separator; $platform):
  split($separator) | map(select(. != "") | if $platform then sub("^linux/"; "") else . end | code(128))
  | reduce .[] as $item ({items: [], size: 0, omitted: false};
      if (.size + ($item | length) + 3) <= 220 then
        .items += [$item] | .size += ($item | length) + 3
      else .omitted = true end)
  | (.items | join(" · ")) + (if .omitted then " · ..." else "" end);

def supporting_fields($published):
  ([if $published and $tags != "" then "**Tags: 🏷️** " + ($tags | code_list("\n"; false)) else empty end,
    if ($notification_type | startswith("image-")) and $platforms != "" then "**Platforms:** **🧱** " + ($platforms | code_list(","; true)) else empty end,
    if $workflow_name != "" then "**Workflow: ⚙️** " + ($workflow_name | text(120)) else empty end]
    | map(select(. != "")) | join("\n")) as $support
  | if $support != "" then [field("\u200b"; $support; false)] else [] end;

def image_fields:
  ($notification_type == "image-verdict" and $publication_status == "success" and $digest != "unconfirmed") as $published
  | context_fields
  + [field("🧾 Details";
      (["**Image:** **🐳** " + ($image_name | text(120))]
        + (if $notification_type == "image-verdict" then
            ["**GHCR:** " + ($publication_status | status_text)]
            + (if $dockerhub_url != "unavailable" then ["**Docker Hub:** " + ($mirror_status | status_text)] else [] end)
          else [] end) | join("\n")); true)]
  + supporting_fields($published)
  + (if $notification_type == "image-start" then
      [field("📦 Registry targets";
        (["**GHCR: 📦** " + ($ghcr_image | code(120))]
          + (if $dockerhub_image != "" then ["**Docker Hub: 🐳** " + ($dockerhub_image | code(120))] else [] end) | join("\n")); false)]
    else [] end)
  + (if $published then [field("🧾 Digest"; ($digest | text(300)); false)] else [] end);

def docs_fields:
  context_fields
  + [field("🧾 Details";
      (["**Project: 📖** " + (($notification.subject // $image_name) | text(120)), "**Target: 🗺️** GitHub Pages"]
        + (if $notification_type == "docs-verdict" then
            ["**Build:** " + ($build_status | status_text), "**Pages:** " + ($deploy_status | status_text)]
          else [] end) | join("\n")); true)]
  + supporting_fields(false);

def quick_links:
  ([link("View run"; $url)]
    + (if $notification_type | startswith("docs-") then [link("Open documentation"; $site_url)]
      else [link("GHCR image"; $ghcr_url), link("Docker Hub image"; $dockerhub_url)] end)
    | map(select(. != "")) | join(" · ")) as $links
  | if $links != "" then [field("🔗 Quick links"; $links; false)] else [] end;

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
      color: $notification.color,
      fields: ((if $failure_stage != "" and $outcome != "start" and $outcome != "success" then [field("⚠️ Stage needing attention"; ($failure_stage | text(120)); false)] else [] end)
        + (if $notification_type | startswith("docs-") then docs_fields else image_fields end)
        + quick_links),
      footer: {text: $notification.footer},
      timestamp: now | todate
    } + (if $url | safe_url then {url: $url} else {} end)]
  };
