#!/usr/bin/env bash
set -euo pipefail

CAMPAIGN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$CAMPAIGN_DIR/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"

exec "$GODOT_BIN" --path "$PROJECT_DIR" res://addons/hotn3_campaign/CampaignRoot.tscn
