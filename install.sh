#!/bin/bash

# ==============================================================================
# TafreshiCID Modifier - Automated Installer for Issabel/Asterisk
# Author: Tafreshi (ertebatcenter.com)
# ==============================================================================

echo "======================================================="
echo "   TafreshiCID Modifier Installer (Issabel/Asterisk)   "
echo "======================================================="
echo ""

# 1. Download and apply the Dialplan context
echo "[1/4] Adding [tafreshicid] context to extensions_custom.conf..."

# Checking if context already exists to avoid duplication
if grep -q "\[tafreshicid\]" /etc/asterisk/extensions_custom.conf; then
    echo "Context [tafreshicid] already exists. Skipping insertion."
else
    cat << 'EOF' >> /etc/asterisk/extensions_custom.conf

; --- Start TafreshiCID Modifier ---
[tafreshicid]
exten => _X.,1,NoOp(TafreshiCID: Modifying CallerID for Iran)
exten => _X.,n,Set(CALLERID(num)=${CALLERID(num):-10}) ; Keep only last 10 digits
exten => _X.,n,Set(CALLERID(num)=0${CALLERID(num)})   ; Add 0 at the beginning
exten => _X.,n,Goto(from-trunk,${EXTEN},1)
; --- End TafreshiCID Modifier ---

EOF
    echo "Context added successfully."
fi

# 2. Fetch SIP Trunks from Issabel Database
echo ""
echo "[2/4] Fetching SIP Trunks from database..."
# Querying Issabel's Asterisk DB for SIP trunks
TRUNKS=$(mysql -u root asterisk -N -B -e "SELECT DISTINCT id FROM sip WHERE keyword='host' AND id NOT LIKE '%_custom';")

if [ -z "$TRUNKS" ]; then
    echo "Error: No SIP trunks found in the database!"
    exit 1
fi

# 3. Create an interactive menu for trunk selection
echo ""
echo "Please select the Trunk you want to apply the CallerID fix to:"
select TRUNK_NAME in $TRUNKS "Exit"; do
    if [ "$TRUNK_NAME" = "Exit" ]; then
        echo "Exiting installation."
        exit 0
    elif [ -n "$TRUNK_NAME" ]; then
        echo "You selected: $TRUNK_NAME"
        break
    else
        echo "Invalid selection. Please try again."
    fi
done

# 4. Update Trunk Context in Database
echo ""
echo "[3/4] Updating context for trunk '$TRUNK_NAME' to 'tafreshicid'..."

# Check if context keyword exists for this trunk, update it, or insert if missing
CONTEXT_EXISTS=$(mysql -u root asterisk -N -B -e "SELECT count(*) FROM sip WHERE id='$TRUNK_NAME' AND keyword='context';")

if [ "$CONTEXT_EXISTS" -gt 0 ]; then
    mysql -u root asterisk -e "UPDATE sip SET data='tafreshicid' WHERE id='$TRUNK_NAME' AND keyword='context';"
else
    mysql -u root asterisk -e "INSERT INTO sip (id, keyword, data, flags) VALUES ('$TRUNK_NAME', 'context', 'tafreshicid', 2);"
fi

echo "Database updated successfully."

# 5. Apply Changes (Reload Asterisk & FreePBX core)
echo ""
echo "[4/4] Applying changes and reloading system..."
/var/lib/asterisk/bin/retrieve_conf > /dev/null 2>&1
asterisk -rx "core reload" > /dev/null 2>&1

echo ""
echo "======================================================="
echo " Installation Complete! CallerID is now normalized."
echo " Visit ertebatcenter.com for more VoIP solutions."
echo "======================================================="
