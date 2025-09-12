#!/usr/bin/env bash

# Colors for output
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
NOCOLOR=$(tput sgr0)

# Constants
REGISTER_TOOL_DIR=$(dirname "$(realpath "$0")")
INSTALLED_SCRIPTS_FILE="$REGISTER_TOOL_DIR/installed_scripts"
BIN_DIR="/usr/local/bin"
ZSHRC_FILE="$HOME/.zshrc"

# Usage function
show_usage() {
    echo -e "${BLUE}Tool Registry Manager${NOCOLOR}"
    echo "Usage: $0 [COMMAND] [SCRIPT_PATH]"
    echo ""
    echo "Commands:"
    echo "  install <script_path>   Register and install a new tool"
    echo "  remove <script_name>    Remove a registered tool"
    echo "  list                    List all registered tools"
    echo "  help                    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 install ./my-script.sh"
    echo "  $0 remove my-script.sh"
    echo "  $0 list"
}

# Migrate old format registry to new format
migrate_registry() {
    if [ ! -f "$INSTALLED_SCRIPTS_FILE" ]; then
        return 0
    fi
    
    # Check if file has old format entries (lines without pipes)
    local has_old_format=false
    while IFS= read -r line; do
        if [ -n "$line" ] && [[ "$line" != *"|"* ]]; then
            has_old_format=true
            break
        fi
    done < "$INSTALLED_SCRIPTS_FILE"
    
    if [ "$has_old_format" = true ]; then
        echo -e "${YELLOW}Migrating registry to new format...${NOCOLOR}"
        
        # Create backup
        cp "$INSTALLED_SCRIPTS_FILE" "${INSTALLED_SCRIPTS_FILE}.backup"
        
        # Create temporary file for new format
        local temp_file=$(mktemp)
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Convert old entries to new format
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                if [[ "$line" == *"|"* ]]; then
                    # Already new format, keep as-is
                    echo "$line" >> "$temp_file"
                else
                    # Old format, convert to new
                    if [ -f "$line" ]; then
                        local script_name=$(basename "$line")
                        local script_alias=${script_name%.sh}
                        echo "$line|$script_name|$script_alias|$timestamp" >> "$temp_file"
                    fi
                fi
            fi
        done < "$INSTALLED_SCRIPTS_FILE"
        
        # Replace old file with migrated content
        mv "$temp_file" "$INSTALLED_SCRIPTS_FILE"
        
        echo -e "${GREEN}✓ Registry migrated successfully${NOCOLOR}"
        echo -e "  Backup saved as: ${BLUE}${INSTALLED_SCRIPTS_FILE}.backup${NOCOLOR}"
    fi
}

# Initialize the installed_scripts file if it doesn't exist
init_registry() {
    if [ ! -f "$INSTALLED_SCRIPTS_FILE" ]; then
        touch "$INSTALLED_SCRIPTS_FILE"
        echo -e "${GREEN}Created registry file: $INSTALLED_SCRIPTS_FILE${NOCOLOR}"
    else
        # Migrate existing file if needed
        migrate_registry
    fi
}

# Function to add tool entry to registry
add_to_registry() {
    local script_path="$1"
    local script_name="$2"
    local script_alias="$3"
    
    # Format: script_path|script_name|script_alias|timestamp
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$script_path|$script_name|$script_alias|$timestamp" >> "$INSTALLED_SCRIPTS_FILE"
}

# Function to remove tool entry from registry
remove_from_registry() {
    local script_name="$1"
    local temp_file=$(mktemp)
    
    # Remove entries that match the script name
    grep -v "|$script_name|" "$INSTALLED_SCRIPTS_FILE" > "$temp_file" 2>/dev/null || true
    mv "$temp_file" "$INSTALLED_SCRIPTS_FILE"
}

# Function to check if tool is already registered
is_tool_registered() {
    local script_name="$1"
    grep -q "|$script_name|" "$INSTALLED_SCRIPTS_FILE" 2>/dev/null
}

# Function to get tool info from registry
get_tool_info() {
    local script_name="$1"
    grep "|$script_name|" "$INSTALLED_SCRIPTS_FILE" 2>/dev/null | head -1
}

# Function to install a tool
install_tool() {
    local input_path="$1"
    
    if [ -z "$input_path" ]; then
        echo -e "${RED}Error: Script path is required${NOCOLOR}"
        show_usage
        exit 1
    fi
    
    # Get the absolute path of the script being registered
    local script_path=$(realpath "$input_path" 2>/dev/null)
    
    # Check if the script file exists
    if [ ! -f "$script_path" ]; then
        echo -e "${RED}Error: Script file not found: $input_path${NOCOLOR}"
        exit 1
    fi
    
    # Get script info
    local script_name=$(basename "$script_path")
    local script_dir=$(dirname "$script_path")
    local script_alias=${script_name%.sh}
    
    # Check if already registered
    if is_tool_registered "$script_name"; then
        echo -e "${YELLOW}Tool $script_name is already registered. Updating...${NOCOLOR}"
        remove_tool_internal "$script_name"
    fi
    
    # Make the script executable
    chmod a+x "$script_path"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to make script executable${NOCOLOR}"
        exit 1
    fi
    
    # Remove existing symlink if it exists
    if [ -L "$BIN_DIR/$script_name" ]; then
        sudo rm "$BIN_DIR/$script_name"
    fi
    
    # Create new symbolic link
    sudo ln -s "$script_path" "$BIN_DIR/$script_name"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to create symbolic link${NOCOLOR}"
        exit 1
    fi
    
    # Add alias to ~/.zshrc if it doesn't exist
    local alias_line="alias $script_alias='$BIN_DIR/$script_name'"
    if ! grep -Fxq "$alias_line" "$ZSHRC_FILE" 2>/dev/null; then
        echo "$alias_line" >> "$ZSHRC_FILE"
        echo -e "${GREEN}Added alias for $script_alias to ~/.zshrc${NOCOLOR}"
    else
        echo -e "${GREEN}Alias for $script_alias already exists in ~/.zshrc${NOCOLOR}"
    fi
    
    # Add PATH export to ~/.zshrc if it doesn't exist
    local path_line='export PATH="/usr/local/bin:$PATH"'
    if ! grep -Fxq "$path_line" "$ZSHRC_FILE" 2>/dev/null; then
        echo "$path_line" >> "$ZSHRC_FILE"
        echo -e "${GREEN}Added PATH export line to ~/.zshrc${NOCOLOR}"
    fi
    
    # Add to registry
    add_to_registry "$script_path" "$script_name" "$script_alias"
    
    echo -e "${GREEN}✓ Successfully registered $script_name${NOCOLOR}"
    echo -e "  Path: ${BLUE}$script_path${NOCOLOR}"
    echo -e "  Alias: ${BLUE}$script_alias${NOCOLOR}"
    echo -e "  Location: ${BLUE}$script_dir${NOCOLOR}"
}

# Internal function to remove tool (without user confirmation)
remove_tool_internal() {
    local script_name="$1"
    
    # Get tool info from registry
    local tool_info=$(get_tool_info "$script_name")
    if [ -z "$tool_info" ]; then
        return 1
    fi
    
    local script_alias=$(echo "$tool_info" | cut -d'|' -f3)
    
    # Remove symlink
    if [ -L "$BIN_DIR/$script_name" ]; then
        sudo rm "$BIN_DIR/$script_name"
    fi
    
    # Remove alias from ~/.zshrc
    local alias_line="alias $script_alias='$BIN_DIR/$script_name'"
    if [ -f "$ZSHRC_FILE" ]; then
        sed -i.bak "\|^$alias_line$|d" "$ZSHRC_FILE"
    fi
    
    # Remove from registry
    remove_from_registry "$script_name"
    
    return 0
}

# Function to remove a tool
remove_tool() {
    local script_name="$1"
    
    if [ -z "$script_name" ]; then
        echo -e "${RED}Error: Script name is required${NOCOLOR}"
        show_usage
        exit 1
    fi
    
    # Check if tool is registered
    if ! is_tool_registered "$script_name"; then
        echo -e "${RED}Error: Tool $script_name is not registered${NOCOLOR}"
        list_tools
        exit 1
    fi
    
    # Get tool info
    local tool_info=$(get_tool_info "$script_name")
    local script_path=$(echo "$tool_info" | cut -d'|' -f1)
    local script_alias=$(echo "$tool_info" | cut -d'|' -f3)
    
    echo -e "${YELLOW}Removing tool: $script_name${NOCOLOR}"
    echo -e "  Path: $script_path"
    echo -e "  Alias: $script_alias"
    
    # Confirm removal
    read -p "Are you sure you want to remove this tool? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if remove_tool_internal "$script_name"; then
            echo -e "${GREEN}✓ Successfully removed $script_name${NOCOLOR}"
        else
            echo -e "${RED}Error: Failed to remove $script_name${NOCOLOR}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Removal cancelled${NOCOLOR}"
    fi
}

# Function to list all registered tools
list_tools() {
    echo -e "${BLUE}Registered Tools:${NOCOLOR}"
    echo "==============================================================================================" 
    
    if [ ! -f "$INSTALLED_SCRIPTS_FILE" ] || [ ! -s "$INSTALLED_SCRIPTS_FILE" ]; then
        echo -e "${YELLOW}No tools registered yet${NOCOLOR}"
        return
    fi
    
    # Print header
    printf "%-20s %-15s %-15s %s\n" "ALIAS" "STATUS" "INSTALLED" "PATH"
    echo "----------------------------------------------------------------------------------------------"
    
    local count=0
    while IFS='|' read -r script_path script_name script_alias timestamp; do
        if [ -n "$script_name" ]; then
            count=$((count + 1))
            
            # Check if symlink still exists
            local status_text
            local status_color
            if [ -L "$BIN_DIR/$script_name" ]; then
                status_text="✓ Active"
                status_color="${GREEN}✓ Active${NOCOLOR}"
            else
                status_text="✗ Missing"
                status_color="${RED}✗ Missing${NOCOLOR}"
            fi
            
            # Format timestamp to be shorter (just date)
            local short_date=$(echo "$timestamp" | cut -d' ' -f1)
            
            # Print row with proper alignment using plain text for alignment and colors for display
            printf "${BLUE}%-20s${NOCOLOR} %-28s %-15s %s\n" \
                "$script_alias" \
                "$status_color" \
                "$short_date" \
                "$script_path"
        fi
    done < "$INSTALLED_SCRIPTS_FILE"
    
    if [ $count -eq 0 ]; then
        echo -e "${YELLOW}No tools registered yet${NOCOLOR}"
    else
        echo "----------------------------------------------------------------------------------------------"
        echo -e "${BLUE}Total: $count tools${NOCOLOR}"
    fi
}

# Main script logic
main() {
    init_registry
    
    case "${1:-help}" in
        "install")
            install_tool "$2"
            ;;
        "remove")
            remove_tool "$2"
            ;;
        "list")
            list_tools
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        *)
            # Backward compatibility - if first argument is a file, treat as install
            if [ -f "$1" ]; then
                install_tool "$1"
            else
                echo -e "${RED}Error: Unknown command '$1'${NOCOLOR}"
                show_usage
                exit 1
            fi
            ;;
    esac
}

# Run main function with all arguments
main "$@"