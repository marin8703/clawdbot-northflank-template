#!/bin/bash
# Ensure workspace points to persistent volume before OpenClaw starts.
# On Northflank, the default workspace path is ephemeral (recreated each restart).
# /data/workspace is on the persistent volume.

PERSISTENT_WORKSPACE="/data/workspace"

# Derive ephemeral workspace from env vars (same logic as OpenClaw/wrapper)
if [ -n "$OPENCLAW_WORKSPACE_DIR" ]; then
    EPHEMERAL_WORKSPACE="$OPENCLAW_WORKSPACE_DIR"
else
    EPHEMERAL_WORKSPACE="/root/.openclaw/workspace"
fi

# Only act if the persistent workspace exists (post-setup) and differs from ephemeral
if [ -d "$PERSISTENT_WORKSPACE" ] && [ "$PERSISTENT_WORKSPACE" != "$EPHEMERAL_WORKSPACE" ]; then
    if [ -L "$EPHEMERAL_WORKSPACE" ]; then
        # Symlink exists — verify it points to the right place
        CURRENT_TARGET=$(readlink "$EPHEMERAL_WORKSPACE")
        if [ "$CURRENT_TARGET" != "$PERSISTENT_WORKSPACE" ]; then
            rm -f "$EPHEMERAL_WORKSPACE"
            ln -s "$PERSISTENT_WORKSPACE" "$EPHEMERAL_WORKSPACE"
        fi
    elif [ -d "$EPHEMERAL_WORKSPACE" ]; then
        # Ephemeral dir exists — copy ALL files to persistent before replacing
        find "$EPHEMERAL_WORKSPACE" -maxdepth 1 -type f | while read -r f; do
            BASENAME=$(basename "$f")
            if [ ! -f "$PERSISTENT_WORKSPACE/$BASENAME" ]; then
                cp "$f" "$PERSISTENT_WORKSPACE/$BASENAME"
            fi
        done
        rm -rf "$EPHEMERAL_WORKSPACE"
        ln -s "$PERSISTENT_WORKSPACE" "$EPHEMERAL_WORKSPACE"
    else
        # Path doesn't exist, or is a broken symlink/regular file — clean up and create
        rm -f "$EPHEMERAL_WORKSPACE" 2>/dev/null
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
