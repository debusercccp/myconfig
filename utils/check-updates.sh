#!/bin/bash
# Check for available system updates and notify via dunst
# Place in ~/.config/scripts/check-updates.sh and make executable

# Update package list quietly
apt update -qq 2>/dev/null

# Count available upgrades
upgradable=$(apt list --upgradable 2>/dev/null | grep -c "upgradable")
security=$(apt list --upgradable 2>/dev/null | grep -c "security")

# Build notification message
if [ "$upgradable" -gt 0 ]; then
    if [ "$security" -gt 0 ]; then
        urgency="critical"
        icon="dialog-warning"
        title="System Updates Available (Security!)"
        body="<b>$upgradable</b> packages can be upgraded (<b>$security</b> security updates)\nRun: <b>aggiorna</b>"
    else
        urgency="normal"
        icon="software-update-available"
        title="System Updates Available"
        body="<b>$upgradable</b> packages can be upgraded\nRun: <b>aggiorna</b>"
    fi

    # Send notification via dunst (notify-send)
    notify-send \
        --app-name="Update Notification" \
        --icon="$icon" \
        --urgency="$urgency" \
        --expire-time=0 \
        "$title" "$body"

    # Also log to journal for reference
    logger -t "update-check" "$upgradable packages upgradable ($security security)"
else
    logger -t "update-check" "System is up to date"
fi
