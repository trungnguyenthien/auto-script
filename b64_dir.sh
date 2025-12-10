#!/bin/bash

# Script to encode files in a directory to base64
# Usage: ./b64_dir.sh <directory_path>
# Compatible with macOS ARM

# Function to display usage
show_usage() {
    echo "Usage: $0 <directory_path>"
    echo "This script will encode all files in the specified directory to base64"
    echo "The base64 files will be saved with .b64 extension in the same directory"
    exit 1
}

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if directory parameter is provided
if [ $# -ne 1 ]; then
    echo "Error: Directory parameter is required"
    show_usage
fi

TARGET_DIR="$1"

# Check if the provided path is a directory
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: '$TARGET_DIR' is not a valid directory"
    exit 1
fi

# Check if directory is readable
if [ ! -r "$TARGET_DIR" ]; then
    echo "Error: Cannot read directory '$TARGET_DIR'"
    exit 1
fi

log_message "Starting base64 encoding for files in: $TARGET_DIR"

# Counter for processed files
processed_count=0
error_count=0

# Process each file in the directory (non-recursive)
for file_path in "$TARGET_DIR"/*; do
    # Skip if not a regular file (skip directories, symlinks, etc.)
    if [ ! -f "$file_path" ]; then
        continue
    fi
    
    # Get the filename
    filename=$(basename "$file_path")
    
    # Skip files that already have .b64 extension to avoid infinite loop
    if [[ "$filename" == *.b64 ]]; then
        log_message "Skipping already encoded file: $filename"
        continue
    fi
    
    # Create output filename
    output_file="${file_path}.b64"
    
    log_message "Processing: $filename"
    
    # Check if file is readable
    if [ ! -r "$file_path" ]; then
        log_message "Warning: Cannot read file '$filename', skipping..."
        ((error_count++))
        continue
    fi
    
    # Encode file to base64
    if base64 -i "$file_path" -o "$output_file"; then
        log_message "Successfully encoded: $filename -> $filename.b64"
        ((processed_count++))
    else
        log_message "Error: Failed to encode file '$filename'"
        ((error_count++))
    fi
done

# Summary
log_message "Processing complete!"
log_message "Files processed: $processed_count"
if [ $error_count -gt 0 ]; then
    log_message "Errors encountered: $error_count"
fi

# Exit with appropriate code
if [ $error_count -eq 0 ]; then
    log_message "All files processed successfully"
    exit 0
else
    log_message "Some errors occurred during processing"
    exit 1
fi