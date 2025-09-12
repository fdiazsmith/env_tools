#!/usr/bin/env bash

# Function to check if an entry should be ignored
should_ignore() {
    local entry="$1"
    shift
    local patterns=("$@")

    for pattern in "${patterns[@]}"; do
        if [[ "$(basename "$entry")" == $pattern ]]; then
            return 0
        fi
    done

    return 1
}

# Function to check if an entry matches the match patterns
should_match() {
    local entry="$1"
    shift
    local patterns=("$@")

    # If no match patterns are provided, include all files
    if [[ ${#patterns[@]} -eq 0 ]]; then
        return 0
    fi

    for pattern in "${patterns[@]}"; do
        if [[ "$(basename "$entry")" == $pattern ]]; then
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
            print_structure "$entry" "$prefix|  " "${ignore[@]}"
        else
            echo "${prefix}|-$(basename "$entry")"
        fi
    done
}

# Function to print text file contents
print_text_files() {
    local dir="$1"
    shift
    local ignore=("$@")

    for entry in "$dir"/*; do
        if should_ignore "$entry" "${ignore[@]}"; then
            continue
        fi

        if [ -d "$entry" ]; then
            print_text_files "$entry" "${ignore[@]}"
        else
            if file "$entry" | grep -q 'text'; then
                if should_match "$entry" "${match_patterns[@]}"; then
                    echo "

FILE START: $entry

"
                    cat "$entry"
                    echo
                fi
            fi
        fi
    done
}

# Function to get the absolute path of a directory
get_absolute_path() {
    local dir="$1"
    echo "$(cd "$dir" && pwd)"
}

# Function to display help message
display_help() {
    echo "Usage: dir2clipboard [OPTIONS]"
    echo
    echo "Analyze the current directory structure and text file contents, and copy the output to the clipboard."
    echo
    echo "Options:"
    echo "  -i, --ignore <pattern>   Ignore entries matching the specified pattern (can be used multiple times)"
    echo "      --match <pattern>    Include only files matching the specified pattern (can be used multiple times)"
    echo "  -m, --min                Remove whitespace and carriage returns from the output"
    echo "  -h, --help               Display this help message"
    echo
}

# Initialize arrays
ignore_patterns=()
match_patterns=()
minify_output=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--ignore)
            shift
            ignore_patterns+=("$1")
            shift
            ;;
        --match)
            shift
            match_patterns+=("$1")
            shift
            ;;
        -m|--min)
            minify_output=true
            shift
            ;;
        -h|--help)
            display_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            display_help
            exit 1
            ;;
    esac
done

# Get the current directory
current_dir=$(get_absolute_path ".")

# Analyze the current directory and print structure
output=$(print_structure "$current_dir" "" "${ignore_patterns[@]}")

# Print text file contents
text_contents=$(print_text_files "$current_dir" "${ignore_patterns[@]}")

# Combine structure and text contents
final_output="$output
$text_contents"

# Minify the output if requested
if [[ "$minify_output" == true ]]; then
    final_output=$(echo "$final_output" | tr -d '[:space:]')
fi

# Copy the final output to the clipboard
echo "$final_output" | pbcopy