#!/bin/bash
# Install systemd user service and timer for automatic update notifications
# Run once to set up automatic daily update checks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$HOME/.config/systemd/user"

echo "Installing update notification service..."

# Create systemd user directory
mkdir -p "$SERVICE_DIR"

# Copy service and timer files
cp "$SCRIPT_DIR/../systemd/user/update-notify.service" "$SERVICE_DIR/"
cp "$SCRIPT_DIR/../systemd/user/update-notify.timer" "$SERVICE_DIR/"

# Reload systemd user daemon
systemctl --user daemon-reload

# Enable and start timer
systemctl --user enable --now update-notify.timer

echo "Installation complete."
echo ""
echo "Timer status:"
systemctl --user status update-notify.timer --no-pager
echo ""
echo "To test notification now: $SCRIPT_DIR/test-update-notify.sh"
echo "To view logs: journalctl --user -u update-notify.service -f"
