#!/bin/bash

# Function to log messages with timestamps
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log "Checking if the JottaWorld process is running..."

# Check if the JottaWorld process is running (since this is the actual process name)
if pgrep -x "JottaWorld" > /dev/null; then
    log "JottaWorld is running. Attempting to quit the Jotta app..."

    # Quit the "Jotta" application (since the bundle is named Jotta)
    osascript -e 'quit app "Jotta"' || log "Failed to quit Jotta."

    # Wait until the JottaWorld process is no longer running
    log "Waiting for the JottaWorld process to completely close..."
    while pgrep -x "JottaWorld" > /dev/null; do
        sleep 1
    done
    log "JottaWorld has fully closed."
else
    log "JottaWorld is not running."
fi

# Restart the "Jotta" application, regardless of whether it was running or not
log "Attempting to restart Jotta..."
osascript -e 'tell application "Jotta" to activate' || log "Failed to restart Jotta."

log "Script finished."
