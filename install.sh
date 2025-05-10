#!/bin/bash
#
# Hectogon - Simplified Installation script
# Developer: AnmiTaliDev
#

# Включаем детальное отслеживание выполнения
set -x

# Default installation paths
PREFIX="/usr/local"
SYSCONFDIR="/etc"
BINDIR="$PREFIX/bin"
DATADIR="/usr/share/hectogon"
MODULEDIR="$DATADIR/modules"
CONFIGDIR="$SYSCONFDIR/hectogon"

echo "Installing Hectogon..."
echo "Installation paths:"
echo "  Prefix:        $PREFIX"
echo "  Binary:        $BINDIR"
echo "  Modules:       $MODULEDIR"
echo "  Configuration: $CONFIGDIR"
echo ""

# Create directories step by step using install
echo "Creating directories..."
install -d "$BINDIR" || { echo "Failed to create $BINDIR"; exit 1; }
echo "Created $BINDIR"

install -d "$DATADIR" || { echo "Failed to create $DATADIR"; exit 1; }
echo "Created $DATADIR"

install -d "$MODULEDIR" || { echo "Failed to create $MODULEDIR"; exit 1; }
echo "Created $MODULEDIR"

install -d "$CONFIGDIR" || { echo "Failed to create $CONFIGDIR"; exit 1; }
echo "Created $CONFIGDIR"

# Install executable
echo "Installing executable..."
if [ ! -f "src/hectogon" ]; then
    echo "Error: src/hectogon not found"
    exit 1
fi

install -m 755 src/hectogon "$BINDIR/hectogon" || { echo "Failed to install src/hectogon to $BINDIR"; exit 1; }
echo "Installed executable to $BINDIR/hectogon"

# Install modules
echo "Installing modules..."
if [ -d "modules" ]; then
    for module in modules/*.sh; do
        if [ -f "$module" ]; then
            install -m 644 "$module" "$MODULEDIR/" || { echo "Failed to install $module to $MODULEDIR"; exit 1; }
            echo "Installed module: $(basename "$module")"
        fi
    done
else
    echo "Warning: modules directory not found"
fi

echo "Installation complete!"
echo "You can now use Hectogon:"
echo "  $BINDIR/hectogon help  - Show help"
echo "  $BINDIR/hectogon list  - List available modules"