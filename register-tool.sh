#!/usr/bin/env bash

RED=`tput setaf 1`
GREEN=`tput setaf 2`
NOCOLOR=`tput sgr0`


# Get the absolute path of the script being registered
SCRIPT_PATH=$(realpath "$1")

# Check if the script file exists
if [ ! -f "$SCRIPT_PATH" ]; then
    echo -e "${RED}Error: Script file not found: $1${NOCOLOR}"
    exit 1
fi

# Get the directory where the script is located
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

# Get the script name
SCRIPT_NAME=$(basename "$SCRIPT_PATH")

# Get the directory where the register-tool.sh script is located
REGISTER_TOOL_DIR=$(dirname "$(realpath "$0")")

# Check if the installed_scripts file exists, create it if it doesn't
if [ ! -f "$REGISTER_TOOL_DIR/installed_scripts" ]; then
    touch "$REGISTER_TOOL_DIR/installed_scripts"
fi

# Check if the script is already registered in the installed_scripts file
if grep -Fxq "$SCRIPT_PATH" "$REGISTER_TOOL_DIR/installed_scripts"; then
    # If the script is already registered, remove it from the file
    sed -i.bak "\:$SCRIPT_PATH:d" "$REGISTER_TOOL_DIR/installed_scripts"
fi

# Add the script to the installed_scripts file in the register-tool.sh directory
echo "$SCRIPT_PATH" >> "$REGISTER_TOOL_DIR/installed_scripts"

# Make the script executable
chmod a+x "$SCRIPT_PATH"

# Check if a symbolic link for the script already exists in /usr/local/bin
if [ -L "/usr/local/bin/$SCRIPT_NAME" ]; then
    # Remove the existing symbolic link
    sudo rm "/usr/local/bin/$SCRIPT_NAME"
fi

# Create a new symbolic link in /usr/local/bin
sudo ln -s "$SCRIPT_PATH" "/usr/local/bin/$SCRIPT_NAME"

# Get the script name without the .sh extension
SCRIPT_ALIAS=${SCRIPT_NAME%.sh}

# Check if the alias already exists in ~/.zshrc
if grep -Fxq "alias $SCRIPT_ALIAS='/usr/local/bin/$SCRIPT_NAME'" ~/.zshrc; then
    echo -e "${GREEN}Alias for $SCRIPT_ALIAS already exists in ~/.zshrc${NOCOLOR}"
else
    # Add the alias to ~/.zshrc
    echo "alias $SCRIPT_ALIAS='/usr/local/bin/$SCRIPT_NAME'" >> ~/.zshrc
    echo -e "${GREEN}Added alias for $SCRIPT_ALIAS to ~/.zshrc${NOCOLOR}"
fi

# Check if the PATH export line already exists in ~/.zshrc
if grep -Fxq 'export PATH="/usr/local/bin:$PATH"' ~/.zshrc; then
    echo -e "${GREEN}PATH export line already exists in ~/.zshrc${NOCOLOR}"
else
    # Add the PATH export line to ~/.zshrc
    echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc
    echo -e "${GREEN}Added PATH export line to ~/.zshrc${NOCOLOR}"
fi

echo -e "Added ${GREEN}$SCRIPT_NAME${NOCOLOR} located in ${GREEN}$SCRIPT_DIR${NOCOLOR} to the local bin folder"