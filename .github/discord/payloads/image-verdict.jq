#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# image-verdict.jq: Render the shared Discord embed for an image publication
#                   success or failure.
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
      {name: "🏷️ Tags", value: $tags, inline: false},
      {name: "🧾 Digest", value: $digest, inline: false},
      {name: "📦 GHCR", value: $ghcr_url, inline: false},
      {name: "🐳 Docker Hub", value: $dockerhub_url, inline: false}
    ],
    footer: {text: $notification.footer},
    timestamp: now | todate
  }]
}
