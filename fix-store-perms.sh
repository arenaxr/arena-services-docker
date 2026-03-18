#!/bin/bash
# fix-store-perms.sh
# Safely updates ARENA file store permissions for nginx read access.
# Only targets files and directories that have the restrictive filebrowser defaults.

echo "Scanning for files with strict permissions (640)..."
find ./store -type f -perm 640 -exec chmod -v 644 {} +

echo "Scanning for directories with strict permissions (750)..."
find ./store -type d -perm 750 -exec chmod -v 755 {} +

echo "Permissions successfully updated."
