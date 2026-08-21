#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# docs-verdict.jq: Render the shared Discord embed for documentation build and
#                  deployment results.
#
# Usage: Loaded by .github/scripts/discord-notifier.sh.
#

{
  username: $notification.username,
  embeds: [{
    title: $notification.title,
    description: $description,
    url: $url,
    color: $notification.color,
    fields: [
      {name: $notification.repository_label, value: $repository, inline: true},
      {name: "🌿 Ref", value: $ref, inline: true},
      {name: $notification.build_label, value: $build_status, inline: true},
      {name: $notification.deploy_label, value: $deploy_status, inline: true},
      {name: $notification.site_label, value: $site_url, inline: false}
    ],
    footer: {text: $notification.footer},
    timestamp: now | todate
  }]
}
