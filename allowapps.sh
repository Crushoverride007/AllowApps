#!/bin/bash

# Function to allow an app from an unverified developer
allow_app() {
    local APP_PATH="$1"
    echo "Debug: Checking app path: $APP_PATH"  # Debugging information
    if [ -z "$APP_PATH" ]; then
        echo "No app path provided. Exiting."
        exit 1
    fi
    if [ ! -d "$APP_PATH" ]; then
        echo "The path provided is not a valid app bundle. Exiting."
        exit 1
    fi

    # Add exception for the app and enable it
    echo "Adding exception for: $APP_PATH"
    sudo spctl --add --label "MyAllowedApps" "$APP_PATH"
    sudo spctl --enable --label "MyAllowedApps" "$APP_PATH"
    
    # Remove quarantine attribute
    echo "Removing quarantine attribute for: $APP_PATH"
    sudo xattr -r -d com.apple.quarantine "$APP_PATH"

    # Verify the quarantine was removed
    echo "Verifying quarantine attribute removal"
    if sudo xattr "$APP_PATH" | grep "com.apple.quarantine" &> /dev/null; then
        echo "Failed to remove quarantine attribute. Exiting."
        exit 1
    fi

    echo "App at $APP_PATH has been allowed."
}

# Function to list directories in Applications folder
list_apps_in_applications() {
    local APPLICATIONS_DIR="/Applications"
    echo "Debug: Listing apps in $APPLICATIONS_DIR"  # Debugging information
    find "$APPLICATIONS_DIR" -maxdepth 1 -type d -print
}

# Prompt user to select an app from a list with filtering
select_app() {
    # List all apps in /Applications
    local apps=()
    while IFS= read -r app; do
        apps+=("$app")
    done < <(list_apps_in_applications)

    if [ ${#apps[@]} -eq 0 ]; then
        echo "No apps found in /Applications. Exiting."
        exit 1
    fi

    echo "Debug: Apps found: ${#apps[@]}"  # Debugging information

    local filtered_apps=()
    local app_name
    while :; do
        read -p "Enter part of the app name to filter: " app_name
        filtered_apps=()
        local index=0
        for app in "${apps[@]}"; do
            if [[ "$(basename "$app")" == *"$app_name"* ]]; then
                echo "$index: $(basename "$app")"
                filtered_apps+=("$app")
                index=$((index + 1))
            fi
        done
        if [ ${#filtered_apps[@]} -gt 0 ]; then
            break
        else
            echo "No matches found. Try again."
        fi
    done

    local app_number
    read -p "Select the app number you want to allow: " app_number
    if [[ "$app_number" =~ ^[0-9]+$ ]] && [ "$app_number" -ge 0 ] && [ "$app_number" -lt "${#filtered_apps[@]}" ]; then
        echo "You have selected: ${filtered_apps[$app_number]}"
        APP_PATH="${filtered_apps[$app_number]}"
    else
        echo "Invalid selection. Exiting."
        exit 1
    fi
}

# Get the selected app path
select_app

# Call the function to allow the app
allow_app "$APP_PATH"

# Additional step: Refresh the System Policy Database
echo "Updating system policy database"
sudo spctl --assess --type exec "$APP_PATH"
sudo defaults write /Library/Preferences/com.apple.security GKAutoRearm -bool NO
sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1

echo "Application processing complete."
