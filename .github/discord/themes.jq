#
# Copyright 2025-2026 Scott Gigawatt
#
# SPDX-License-Identifier: Apache-2.0
#
# themes.jq: Store project-specific Discord identities and bounded joke variants.
#
# Usage: Loaded by .github/scripts/discord-notifier.sh with image, profile,
#        notification type, outcome, and deterministic selection inputs.
#

{
  "colors": {
    "start": 0,
    "success": 5763719,
    "failure": 15548997,
    "warning": 16705372,
    "cancelled": 10070709,
    "skipped": 10070709,
    "neutral": 10070709
  },
  "images": {
    "Privateerr": {
      "color": 49919,
      "image-primary": {
        "name": "Tunnel Werkroom",
        "jokes": {
          "start": [
            "The tunnel crew has entered the werkroom.",
            "The tunnel crew brought tools and entirely too much setting spray."
          ],
          "success": [
            "Tunnel couture, with receipts.",
            "The tunnel crew would like a round of applause and better lighting."
          ],
          "failure": [
            "The tunnel crew needs a wardrobe adjustment.",
            "The tunnel crew has notes, and none of them say encore."
          ],
          "cancelled": [
            "The tunnel crew has been called offstage.",
            "The tunnel crew is taking five, heels included."
          ],
          "skipped": [
            "The tunnel crew kept the outfit on its hanger.",
            "The tunnel crew did not make an entrance this time."
          ],
          "neutral": [
            "The tunnel crew is waiting for a clearer brief.",
            "The tunnel crew has requested an actual verdict."
          ],
          "warning": [
            "The tunnel crew needs a closer look at the receipts.",
            "The tunnel crew is checking the fine print, darling."
          ]
        }
      },
      "image-secondary": {
        "name": "Styx Tunnel Authority",
        "jokes": {
          "start": [
            "The Styx Tunnel Authority has opened the paperwork.",
            "The ferryman would like this request in triplicate."
          ],
          "success": [
            "The ferryman stamped the manifest.",
            "The tunnel permit has survived infernal bureaucracy."
          ],
          "failure": [
            "The tunnel permit has reached infernal review.",
            "The ferryman has requested the incident log and exact change."
          ],
          "cancelled": [
            "The ferryman has returned this crossing to the queue.",
            "The Styx Tunnel Authority has put down its stamp."
          ],
          "skipped": [
            "No crossing was booked with the ferryman.",
            "The tunnel permit stayed in the in-tray."
          ],
          "neutral": [
            "The tunnel authority is awaiting a legible verdict.",
            "The ferryman has requested clarification in writing."
          ],
          "warning": [
            "The tunnel authority needs someone to read the small print.",
            "The ferryman has found an unsigned form."
          ]
        }
      }
    },
    "Buccaneerr": {
      "color": 16732120,
      "image-primary": {
        "name": "Quality Queens",
        "jokes": {
          "start": [
            "The quality queens have their clipboards ready.",
            "The inspection crew brought standards and sensible shoes."
          ],
          "success": [
            "The inspection crew approves this ensemble.",
            "The quality queens are putting a gold star on the clipboard."
          ],
          "failure": [
            "The clipboard has notes. Several notes.",
            "The quality queens have requested a private word."
          ],
          "cancelled": [
            "The quality queens have adjourned the inspection.",
            "The clipboards are down, but the eyebrows remain raised."
          ],
          "skipped": [
            "The inspection crew stayed in the green room.",
            "The clipboards remain pristine this round."
          ],
          "neutral": [
            "The quality queens would like a definite answer.",
            "The inspection crew is withholding its dramatic pause."
          ],
          "warning": [
            "The quality queens need another look at the details.",
            "The clipboard has a question mark in very neat handwriting."
          ]
        }
      },
      "image-secondary": {
        "name": "Cerberus Sniff Test",
        "jokes": {
          "start": [
            "Three noses. One suspicious Dockerfile.",
            "Cerberus has assigned one head to each checklist."
          ],
          "success": [
            "Three heads approved it. The tail supplied the signature.",
            "The inspection earned a unanimous tail wag."
          ],
          "failure": [
            "Cerberus found something. Unfortunately, it wasn’t a treat.",
            "Three noses have identified a distinctly unhelpful smell."
          ],
          "cancelled": [
            "Cerberus has put the checklist down for a walk.",
            "The inspection was interrupted by a very important squirrel."
          ],
          "skipped": [
            "Cerberus kept all three noses out of this one.",
            "The checklist stayed beside the dog bowl."
          ],
          "neutral": [
            "Cerberus has three opinions and no final verdict.",
            "The tail has declined to sign an ambiguous report."
          ],
          "warning": [
            "Cerberus wants a second sniff before anyone celebrates.",
            "One head has raised a paw with a question."
          ]
        }
      }
    }
  },
  "docs": {
    "subject": "Privateerr",
    "image": "Privateerr",
    "name": "Read Me, Daddy",
    "jokes": {
      "start": [
        "The reference queens have opened the book.",
        "The footnotes have been told to make an entrance."
      ],
      "success": [
        "Readable, searchable, and ready for your bookmarks.",
        "The footnotes understood the assignment."
      ],
      "failure": [
        "The reference queens have found a page that needs work.",
        "The footnotes have requested a rewrite."
      ],
      "cancelled": [
        "The reference queens have closed the book for now.",
        "The bookmark is holding our place."
      ],
      "skipped": [
        "This edition stayed on the reading list.",
        "The reference desk has no new edition this time."
      ],
      "neutral": [
        "The reference queens would like a clearer ending.",
        "The reference desk is waiting for a definite answer."
      ],
      "warning": [
        "The reference desk has a question before we celebrate.",
        "The reference queens are checking the small print."
      ]
    }
  }
} as $catalog
| $catalog.images[$image_name] as $image
| (if $notification_type | startswith("docs-") then
    if $profile == "docs" then $catalog.docs else null end
  elif $profile == "image-primary" or $profile == "image-secondary" then
    $image[$profile] + {subject: $image_name}
  else null end) as $identity
| ($notification_type | startswith("docs-")) as $docs
| (if $docs then "documentation update" else "image pipeline" end) as $noun
| {start: "started", success: (if $docs then "published" else "published" end), failure: "failed", cancelled: "cancelled", skipped: "skipped", neutral: "ended with a neutral result", warning: "needs attention"}[$outcome] as $state
| if $identity == null or $identity.jokes[$outcome] == null or $state == null then
    error("unsupported Discord notification definition")
  else
    {
      username: ($identity.subject + (if $docs then " Docs" else " Image Builds" end) + " • " + $identity.name),
      subject: $identity.subject,
      title: (({start: "🔨", success: "✅", failure: "❌", cancelled: "⏹️", skipped: "⏭️", neutral: "ℹ️", warning: "⚠️"}[$outcome]) + " " + $identity.subject + " " + (if $outcome == "success" and ($docs | not) then "image" else $noun end) + " " + $state),
      footer: ($identity.name + (if $docs then " • documentation updates" else " • image builds" end)),
      color: (if $outcome == "start" then (if $docs then $catalog.images[$catalog.docs.image].color else $image.color end) else $catalog.colors[$outcome] end),
      message: $identity.jokes[$outcome][$selection % ($identity.jokes[$outcome] | length)]
    }
  end
