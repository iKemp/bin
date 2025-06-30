#!/usr/bin/env bash

# Configuration variables
VPN_HOST="ras.viessmann.com"
XDG_OPEN_SAML_DIR="$HOME/devel/tools/XdgOpenSaml"

# --- Function to gracefully disconnect VPN ---
disconnect_vpn() {
    echo "" # Add a newline for cleaner output after a Ctrl+C or terminal close
    echo "Caught signal to disconnect. Disconnecting VPN..."
    # Use pkill to send SIGTERM to openfortivpn processes
    # This assumes openfortivpn is running with sudo, so pkill needs sudo as well.
    sudo pkill openfortivpn
    echo "VPN disconnected."
    exit 0 # Exit the script cleanly
}

# --- Set up traps for signals ---
# SIGHUP: Hang-up signal, typically sent when a terminal is closed.
# SIGINT: Interrupt signal, typically sent by Ctrl+C.
# SIGTERM: Termination signal, a general request to terminate.
trap disconnect_vpn SIGHUP SIGINT SIGTERM

echo "---------------------------------------------------"
echo "  Starting VPN Connection Script"
echo "  Host: $VPN_HOST"
echo "---------------------------------------------------"

# --- Navigate to XdgOpenSaml directory ---
echo "Changing directory to $XDG_OPEN_SAML_DIR..."
cd "$XDG_OPEN_SAML_DIR" || {
    echo "Error: Could not change to $XDG_OPEN_SAML_DIR. Please check the path."
    exit 1
}
echo "Directory changed."

# --- Execute XdgOpenSaml and pipe to openfortivpn ---
echo "Running XdgOpenSaml to get VPN cookie..."
echo "A browser tab will open for authentication. Please select your Google account manually."

# The 2>/dev/null redirects standard error of XdgOpenSaml to null,
# preventing its error messages (if any) from cluttering your terminal.
./jbang XdgOpenSaml.java "$VPN_HOST" 2>/dev/null | \
    sudo openfortivpn "$VPN_HOST" --cookie-on-stdin --use-resolvconf=1

# This line will only be reached if openfortivpn exits on its own
# (e.g., if the VPN server disconnects it, or if it encounters an unrecoverable error).
echo "---------------------------------------------------"
echo "  VPN connection process ended."
echo "  If you wish to terminate the VPN manually, press Ctrl+C."
echo "---------------------------------------------------"

# The script will effectively pause here as long as openfortivpn is running in the foreground.
# When openfortivpn exits, the script will naturally proceed and then exit.