#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# themes.jq: Store Discord identities, presentation metadata, and randomized
#            copy behind stable destination profiles.
#
# Usage: jq -n --arg profile <profile> --arg notification_type <type> \
#            --arg outcome <outcome> --argjson selection <integer> \
#            -f .github/discord/themes.jq
#

#
# Keep workflow-facing profile names independent from the creative theme. A
# future re-theme changes only this file; workflows and helper arguments remain
# stable. Shared values apply to every notification owned by that profile.
#
{
  "image-primary": {
    shared: {
      theme: "Rainbow Werkroom",
      username: "Rainbow Release Werkroom",
      repository_label: "👑 House"
    },
    notifications: {
      "image-start": {
        start: {
          title: "🌈 Category is: multi-arch realness",
          footer: "Rainbow Werkroom • serving immutable glamour",
          color: 15418782,
          actor_label: "💄 Mother",
          messages: [
            "{{workflow_name}} entered the werkroom. The builders have opinions, the manifests have contour, and beige infrastructure was asked to leave.",
            "Buildx said the category is multi-arch realness. AMD64 brought shoulders; ARM64 brought range and a reveal.",
            "The tags are tucked, the cache is blended, and provenance has arrived with receipts in a rhinestone binder.",
            "CI put on lashes for this. If the pipeline smudges them, there will be a postmortem and several subtweets.",
            "ARM64 and AMD64 are serving matching-image family resemblance with completely different bone structure.",
            "The release pipeline chose glitter, audacity, and reproducible builds. Operations approved two of those things."
          ]
        }
      },
      "image-verdict": {
        success: {
          title: "💖 Images published, edges snatched",
          footer: "Rainbow Werkroom • every platform understood the assignment",
          color: 5763719,
          messages: [
            "Both registries received the images. The digests match, the tags are snatched, and no architecture must lip-sync for its life.",
            "The manifest list served cross-platform versatility, clean lines, and a reveal nobody found in the Dockerfile.",
            "Provenance brought receipts, timestamps, and the confidence of a queen who read the policy before entering the room.",
            "The SBOM walked in last, named every dependency, and still had time to critique the lighting.",
            "Every platform understood the assignment. Even the attestations look expensive.",
            "The release is out, proud, reproducible, and already correcting strangers about immutable tags."
          ]
        },
        failure: {
          title: "🫦 The pipeline lost the lip sync",
          footer: "Rainbow Werkroom • the logs are reading her for filth",
          color: 15548997,
          messages: [
            "The build sashayed away before publication and left only a broken heel, three logs, and no forwarding address.",
            "One layer came unpinned and now the entire pipeline is outside arguing with security in full face.",
            "Publication ended {{job_status}}. The code had charisma, uniqueness, nerve, and an unfortunately nonzero exit status.",
            "The pipeline served face, then served exit code 1, then asked whether retries count as a redemption arc.",
            "The manifest split before judging. GHCR says it needs space; Docker Hub has already changed the locks.",
            "The logs are reading this deployment so thoroughly that the root cause may never recover socially."
          ]
        }
      }
    }
  },
  "image-secondary": {
    shared: {
      theme: "Infernal Helpdesk",
      username: "Infernal Release Helpdesk",
      repository_label: "📁 Case File"
    },
    notifications: {
      "image-start": {
        start: {
          title: "🔥 Ticket INC-666 entered the queue",
          footer: "Infernal Helpdesk • your SLA is eternal",
          color: 15105570,
          actor_label: "🧑‍💻 On-Call Mortal",
          messages: [
            "{{workflow_name}} opened ticket INC-666. Priority is \"whenever the lava cools,\" so naturally everyone is panicking.",
            "Cerberus accepted the build request, ate the duplicate, and assigned the remaining copy to all three heads.",
            "The underworld printer produced a manifest, a prophecy, and seventeen pages of terms nobody living can enforce.",
            "The release entered the infernal queue behind one password reset and the eternal migration from Jenkins.",
            "Three demons approved the change request. The fourth demanded rollback instructions written in blood-compatible Markdown.",
            "The on-call necromancer has begun reanimating cache layers. Please do not ask which Python version they died under."
          ]
        }
      },
      "image-verdict": {
        success: {
          title: "🐕 Cerberus closed the ticket",
          footer: "Infernal Helpdesk • resolved before the heat death of everything",
          color: 5763719,
          messages: [
            "Cerberus approved the digest with all three heads, which is two approvals above policy minimum.",
            "Both registries accepted the offering. Finance has classified the smoke as a normal operating expense.",
            "The change request crossed the Styx, passed validation, and returned with a stamped parking voucher.",
            "The deployment came back from the dead with matching tags and surprisingly healthy boundaries.",
            "Infernal support closed the ticket as resolved, reproducible, and no longer audibly whispering.",
            "The images published successfully. A demon updated the runbook, so please expect four new typos and one curse."
          ]
        },
        failure: {
          title: "💀 Production requested a séance",
          footer: "Infernal Helpdesk • escalation has no known ceiling",
          color: 15548997,
          messages: [
            "The ticket was escalated to someone still alive, which violates several departmental traditions.",
            "The build died twice and still failed to meet the underworld's minimum haunting requirements.",
            "Publication ended {{job_status}}. Cerberus is reviewing the logs one head at a time to maximize blame coverage.",
            "The registry rejected the offering and requested something less cursed, like an unsigned binary from a forum.",
            "Infernal support found the root cause, lost it in a corridor, and has opened a second incident about the corridor.",
            "The rollback crossed the Styx without exact change and is now arguing with a ferryman about semantic versioning."
          ]
        }
      }
    }
  },
  "docs": {
    shared: {
      theme: "Olympian Oracle",
      username: "Oracle of the Developer Charts",
      repository_label: "🏛️ Polis",
      build_label: "🧠 Athena's Review",
      deploy_label: "⚡ Zeus Says",
      site_label: "📜 Prophecy"
    },
    notifications: {
      "docs-verdict": {
        success: {
          title: "🏛️ The Oracle returned green",
          footer: "Olympian Oracle • Athena reviewed the footnotes",
          color: 5793266,
          messages: [
            "Athena reviewed every page, corrected one comma, and declared the architecture wise enough for mortals.",
            "Hermes delivered the documentation to Pages before anyone could invent another deployment meeting.",
            "The Oracle returned green. The prophecy includes valid links, searchable headings, and no unexplained deprecations.",
            "Theseus followed the navigation through every nested section and did not need the emergency ball of red yarn.",
            "Zeus approved the build with one thunderbolt, which GitHub has recorded as a successful deployment annotation.",
            "Sisyphus pushed one final docs build uphill, watched it deploy, and has cautiously enabled out-of-office replies."
          ]
        },
        failure: {
          title: "⚡ Olympus declined the deployment",
          footer: "Olympian Oracle • the incident report calls it hubris",
          color: 15548997,
          messages: [
            "The docs entered the labyrinth without a thread. The sidebar insists this is an intentional information architecture choice.",
            "Apollo delivered the prophecy in deprecated syntax, then blamed a breaking change in the mortal realm.",
            "Hermes dropped the deployment halfway to Pages and marked the package \"left with a neighbor named Hades.\"",
            "Build {{build_status}}, deploy {{deploy_status}}. Olympus has reviewed the evidence and classified it as hubris.",
            "Athena requested the logs, Zeus requested a scapegoat, and Dionysus has already started the incident happy hour.",
            "Sisyphus reached ninety-nine percent, the link checker found one more anchor, and the boulder has resumed its sprint downhill."
          ]
        }
      }
    }
  }
} as $profiles

#
# Resolve one supported notification and select its message by modulo so tests
# can force a deterministic index while live workflows use script randomness.
#
| $profiles[$profile] as $profile_definition
| $profile_definition.notifications[$notification_type][$outcome] as $definition
| if $profile_definition == null or $definition == null then
    error("unsupported Discord notification definition")
  elif ($definition.messages | length) == 0 then
    error("Discord notification message list is empty")
  else
    $profile_definition.shared
      + $definition
      + {message: $definition.messages[$selection % ($definition.messages | length)]}
      | del(.messages)
  end
