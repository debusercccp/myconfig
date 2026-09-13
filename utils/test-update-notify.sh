#!/bin/bash
# Manual test trigger for update notification
# Run this to test the notification immediately

echo "Running update check..."
/home/noya/dotfiles/myconfig/scripts/check-updates.sh
echo "Done. Check dunst notification."
