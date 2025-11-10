#!/usr/bin/env bash
# Using the backend /files upload endpoint to post a large JSON file to the EEWPW backend.
#
# Usage:
#   ./post_large_json.sh [--dry] /path/to/large.json [BACKEND_URL]
#
# Examples:
#   ./post_large_json.sh /path/to/plum_20251106_07.json
#   ./post_large_json.sh --dry /path/to/plum_20251106_07.json http://myserver:8000
#
# If BACKEND_URL is not provided as the second argument, the script will use:
#   1) the EEWPW_BACKEND_URL environment variable, if set, otherwise
#   2) the default: http://localhost:8000
#
# The script performs basic checks and prints a short summary of what it is doing.

set -euo pipefail

DRY_RUN=false

# Parse --dry option
if [[ "${1:-}" == "--dry" ]]; then
    DRY_RUN=true
    shift
fi

usage() {
    echo "Usage: $0 [--dry] /path/to/large.json [BACKEND_URL]"
    echo
    echo "Uploads a large JSON file to the EEWPW backend /files endpoint."
    echo
    echo "Arguments:"
    echo "  --dry                 Optional flag to perform a dry run without uploading."
    echo "  /path/to/large.json   Path to the JSON file to upload."
    echo "  BACKEND_URL           Optional backend base URL (default: http://localhost:8000"
    echo "                        or value from EEWPW_BACKEND_URL if set)."
}

# Check arguments
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
    exit 1
fi

FILE_PATH="$1"
BACKEND_URL="${2:-${EEWPW_BACKEND_URL:-http://localhost:8000}}"

# Basic validation for the file
if [ ! -f "$FILE_PATH" ]; then
    echo "Error: File not found: $FILE_PATH"
    exit 1
fi

# Normalize backend URL to avoid double slashes
BACKEND_URL="${BACKEND_URL%/}"

echo "------------------------------------------------------------"
echo "EEWPW large JSON upload"
echo "  File       : $FILE_PATH"
echo "  Backend URL: ${BACKEND_URL}/files"
echo "------------------------------------------------------------"

if [ "$DRY_RUN" = true ]; then
    echo "Dry run enabled: upload skipped."
    echo
    echo "Dry run complete (no upload performed)."
    exit 0
fi

# Perform the upload
curl -X POST \
     -F "file=@${FILE_PATH}" \
     "${BACKEND_URL}/files"

echo
echo "Upload finished."