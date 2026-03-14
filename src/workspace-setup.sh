#!/bin/bash
# Ensure workspace points to persistent volume before OpenClaw starts.
# On Northflank, /root/.openclaw/workspace is ephemeral (recreated each restart).
# /data/workspace is on the persistent volume.

PERSISTENT_WORKSPACE="/data/workspace"
EPHEMERAL_WORKSPACE="/root/.openclaw/workspace"

# Only act if the persistent workspace exists (post-setup)
if [ -d "$PERSISTENT_WORKSPACE" ]; then
    if [ -L "$EPHEMERAL_WORKSPACE" ]; then
        # Already a symlink — nothing to do
        true
    elif [ -d "$EPHEMERAL_WORKSPACE" ]; then
        # Ephemeral dir exists — save any new templates, then replace with symlink
        for f in SOUL.md USER.md IDENTITY.md TOOLS.md HEARTBEAT.md BOOTSTRAP.md AGENTS.md; do
            if [ -f "$EPHEMERAL_WORKSPACE/$f" ] && [ ! -f "$PERSISTENT_WORKSPACE/$f" ]; then
                cp "$EPHEMERAL_WORKSPACE/$f" "$PERSISTENT_WORKSPACE/$f"
            fi
        done
        rm -rf "$EPHEMERAL_WORKSPACE"
        ln -s "$PERSISTENT_WORKSPACE" "$EPHEMERAL_WORKSPACE"
    else
        # No workspace dir at all — create symlink
        mkdir -p "$(dirname "$EPHEMERAL_WORKSPACE")"
        ln -s "$PERSISTENT_WORKSPACE" "$EPHEMERAL_WORKSPACE"
    fi

    # Ensure required subdirectories exist
    mkdir -p "$PERSISTENT_WORKSPACE/memory" "$PERSISTENT_WORKSPACE/tmp"
fi

# Run any user startup script if it exists on the persistent volume
if [ -x "/data/scripts/container-tools.sh" ]; then
    nohup bash /data/scripts/container-tools.sh > /tmp/container-tools.log 2>&1 &
fi
