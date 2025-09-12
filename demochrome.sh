#!/bin/bash

# Configuration
SCREENSHOT_DIR="$HOME/Desktop/chrome_screenshots"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SCREENSHOT_FILE="$SCREENSHOT_DIR/chrome_dev_${TIMESTAMP}.png"

# Create screenshots directory if it doesn't exist
mkdir -p "$SCREENSHOT_DIR"

# Function to resize Chrome window
resize_chrome() {
    osascript -e '
    tell application "Google Chrome"
        activate
        tell window 1
            set bounds to {0, 23, 1923, 1198}
        end tell
    end tell
    ' 2>/dev/null
}

# Simple and reliable screenshot function
screenshot_chrome() {
    echo "Taking screenshot of Chrome window..."
    
    # Ensure Chrome is the frontmost application
    osascript -e 'tell application "Google Chrome" to activate' 2>/dev/null
    sleep 0.5  # Give it a moment to come to front
    
    # Screenshot the frontmost window (much more reliable)
    screencapture -o -w -c "$SCREENSHOT_FILE"
    
    if [[ $? -eq 0 ]]; then
        echo "Screenshot saved: $SCREENSHOT_FILE"
        # Uncomment to automatically open the screenshot
        # open "$SCREENSHOT_FILE"
    else
        echo "Failed to take screenshot"
    fi
}

# Function to get current window size for debugging
debug_window_size() {
    osascript -e '
    tell application "Google Chrome"
        tell window 1
            set windowBounds to bounds
            set windowWidth to (item 3 of windowBounds) - (item 1 of windowBounds)
            set windowHeight to (item 4 of windowBounds) - (item 2 of windowBounds)
            return "Current bounds: " & windowBounds & " (Width: " & windowWidth & ", Height: " & windowHeight & ")"
        end tell
    end tell
    '
}

# Main script logic
if pgrep -x "Google Chrome" > /dev/null; then
    echo "Chrome is running, attempting to resize..."
    resize_chrome
    sleep 1  # Give window time to resize
    # screenshot_chrome
    echo "Debug info:"
    debug_window_size
else
    echo "Chrome not running, launching new instance..."
    open -n -a "Google Chrome" --args \
      --disable-web-security \
      --user-data-dir="/tmp/ChromeDevSession" \
      --window-size=1920,1080 \
      --window-position=0,0
    
    # Wait for Chrome to fully load
    sleep 3
    resize_chrome
    sleep 1  # Give window time to resize
    # screenshot_chrome
    echo "Debug info:"
    debug_window_size
fi