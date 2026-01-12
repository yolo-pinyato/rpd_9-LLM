#!/bin/bash
# Export Workforce Development App Database to Desktop
# This script finds the most recent database from the iOS Simulator and copies it to Desktop

echo "🔍 Finding most recent workforce_dev.sqlite database..."

# Find all databases and sort by modification time
DB_PATH=$(find ~/Library/Developer/CoreSimulator/Devices/*/data/Containers/Data/Application/*/Documents/workforce_dev.sqlite 2>/dev/null | \
    xargs ls -t 2>/dev/null | head -1)

if [ -z "$DB_PATH" ]; then
    echo "❌ No database found in simulator."
    echo ""
    echo "Please run the app first to create a database."
    exit 1
fi

echo "✅ Found database at:"
echo "   $DB_PATH"
echo ""

# Get database size and modification time
DB_SIZE=$(du -h "$DB_PATH" | cut -f1)
DB_MODIFIED=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$DB_PATH")

echo "📊 Database info:"
echo "   Size: $DB_SIZE"
echo "   Last modified: $DB_MODIFIED"
echo ""

# Create timestamped filename
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DESKTOP_PATH="$HOME/Desktop/workforce_dev_${TIMESTAMP}.sqlite"

# Copy database
echo "📥 Copying to Desktop..."
cp "$DB_PATH" "$DESKTOP_PATH"

if [ $? -eq 0 ]; then
    echo "✅ Database exported successfully!"
    echo ""
    echo "📁 Location: $DESKTOP_PATH"
    echo ""
    echo "You can now:"
    echo "  • Open with: sqlite3 \"$DESKTOP_PATH\""
    echo "  • View with DB Browser: https://sqlitebrowser.org/"
    echo "  • Analyze the data"
    echo ""

    # Show table count
    TABLE_COUNT=$(sqlite3 "$DESKTOP_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null)
    echo "📊 Database contains $TABLE_COUNT tables"

    # List tables
    echo ""
    echo "Tables in database:"
    sqlite3 "$DESKTOP_PATH" ".tables"
else
    echo "❌ Failed to copy database"
    exit 1
fi
