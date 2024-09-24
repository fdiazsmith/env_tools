#!/usr/bin/env bash

# Function to check if an entry should be ignored
should_ignore() {
    local entry="$1"
    shift
    local ignore=("$@")

    for pattern in "${ignore[@]}"; do
        if [[ "$entry" == *"$pattern"* ]]; then
            return 0
        fi
    done

    return 1
}

# Function to print directory structure
print_structure() {
    local dir="$1"
    local prefix="$2"
    shift 2
    local ignore=("$@")

    for entry in "$dir"/*; do
        if should_ignore "$entry" "${ignore[@]}"; then
            continue
        fi

        if [ -d "$entry" ]; then
            echo "${prefix}|-$(basename "$entry")/"
            print_structure "$entry" "$prefix|--" "${ignore[@]}"
        else
            echo "${prefix}|-$(basename "$entry")"
        fi
    done
}

# Function to print text file contents
print_text_files() {
    local dir="$1"
    shift 1
    local ignore=("$@")

    for entry in "$dir"/*; do
        if should_ignore "$entry" "${ignore[@]}"; then
            continue
        fi

        if [ -d "$entry" ]; then
            print_text_files "$entry" "${ignore[@]}"
        else
            if file "$entry" | grep -q 'text'; then
                echo "

        
                
FILE START: $entry

"
                cat "$entry"
                echo
            fi
        fi
    done
}

# Function to get the absolute path of a directory
get_absolute_path() {
    local dir="$1"
    echo "$(cd "$dir" && pwd)"
}

# Collect ignored patterns from arguments
ignore_patterns=()
while [[ "$1" =~ ^-i|--ignore$ ]]; do
    shift
    ignore_patterns+=("$1")
    shift
done

# Get the current directory
current_dir=$(get_absolute_path ".")

# Analyze the current directory and print structure
output=$(print_structure "$current_dir" "" "${ignore_patterns[@]}")
echo "$output"

# Print text file contents
text_contents=$(print_text_files "$current_dir" "${ignore_patterns[@]}")

# Combine structure and text contents
final_output="$output
$text_contents"

# Print the final output
echo "$final_output"

# Copy the final output to the clipboard
echo "$final_output" | pbcopy

# If xclip is not installed, you can install it using:
# sudo apt-get install xclip
# Function to display help message
display_help() {
    echo "Usage: dir2clipboard [OPTIONS]"
    echo
    echo "Analyze the current directory structure and text file contents, and copy the output to the clipboard."
    echo
    echo "Options:"
    echo "  -i, --ignore <pattern>   Ignore entries matching the specified pattern"
    echo "  -h, --help               Display this help message"
    echo
}

# Check if the --help or -h flag is provided
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    display_help
    exit 0
fi