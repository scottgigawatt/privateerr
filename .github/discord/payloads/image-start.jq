#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# image-start.jq: Render the shared Discord embed for an image-build start.
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
      {name: $notification.actor_label, value: $actor, inline: true},
      {name: "🧱 Platforms", value: $platforms, inline: false},
      {name: "📦 GHCR", value: $ghcr_image, inline: false},
      {name: "🐳 Docker Hub", value: $dockerhub_image, inline: false}
    ],
    footer: {text: $notification.footer},
    timestamp: now | todate
  }]
}
