#!/bin/bash

# =========================================================================
# Tafreshi CallerID Normalization Script for Issabel
# =========================================================================

echo "======================================================"
echo "  Tafreshi CallerID Normalization Setup (Issabel)     "
echo "======================================================"

# 1. Get Database Credentials automatically from amportal.conf
echo "[*] Extracting database credentials..."
DB_USER=$(grep -w 'AMPDBUSER' /etc/amportal.conf | cut -d '=' -f2 | tr -d ' ' | tr -d '\r' | tr -d '\n')
DB_PASS=$(grep -w 'AMPDBPASS' /etc/amportal.conf | cut -d '=' -f2 | tr -d ' ' | tr -d '\r' | tr -d '\n')

if [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
    echo "[!] Error: Could not extract database credentials."
    exit 1
fi

# 2. Inject Context into extensions_custom.conf
echo "[*] Injecting 'tafreshicid' context into extensions_custom.conf..."
CUSTOM_CONF="/etc/asterisk/extensions_custom.conf"

if ! grep -q "\[tafreshicid\]" "$CUSTOM_CONF"; then
    cat << 'EOF' >> "$CUSTOM_CONF"

[tafreshicid]
exten => _.,1,NoOp(Tafreshi CallerID Normalization)
exten => _.,n,Set(CALLERID(num)=${CALLERID(num):-10})
exten => _.,n,Set(CALLERID(num)=0${CALLERID(num)})
exten => _.,n,Goto(from-trunk,${EXTEN},1)
EOF
    echo "[+] Context 'tafreshicid' added successfully."
else
    echo "[-] Context 'tafreshicid' already exists. Skipping."
fi

# 3. List available Trunks
echo "------------------------------------------------------"
echo "Available Trunks:"
mysql -u"$DB_USER" -p"$DB_PASS" asterisk -e "SELECT trunkid, name, channelid FROM trunks;"
echo "------------------------------------------------------"

read -p "Enter the 'channelid' of the trunk you want to modify: " TRUNK_CHANNELID

if [ -z "$TRUNK_CHANNELID" ]; then
    echo "[!] No trunk selected. Exiting."
    exit 1
fi

TRUNK_NAME=$(mysql -u"$DB_USER" -p"$DB_PASS" asterisk -se "SELECT name FROM trunks WHERE channelid='$TRUNK_CHANNELID';" | tr -d '\r' | tr -d '\n')

if [ -z "$TRUNK_NAME" ]; then
    echo "[!] Trunk channelid not found in database. Exiting."
    exit 1
fi

# 4. Update Context in sip and pjsip tables (Using DELETE & INSERT for reliability)
echo "[*] Updating Trunk '$TRUNK_NAME' (Channel ID: $TRUNK_CHANNELID) context to 'tafreshicid'..."

# --- Update SIP table ---
mysql -u"$DB_USER" -p"$DB_PASS" asterisk -e "DELETE FROM sip WHERE id='$TRUNK_CHANNELID' AND keyword='context';"
mysql -u"$DB_USER" -p"$DB_PASS" asterisk -e "INSERT INTO sip (id, keyword, data, flags) VALUES ('$TRUNK_CHANNELID', 'context', 'tafreshicid', 0);"

# --- Update PJSIP table (Hide errors if system does not use PJSIP) ---
mysql -u"$DB_USER" -p"$DB_PASS" asterisk -e "DELETE FROM pjsip WHERE id='$TRUNK_CHANNELID' AND keyword='context';" 2>/dev/null
mysql -u"$DB_USER" -p"$DB_PASS" asterisk -e "INSERT INTO pjsip (id, keyword, data, flags) VALUES ('$TRUNK_CHANNELID', 'context', 'tafreshicid', 0);" 2>/dev/null

echo "[+] Trunk updated successfully."

# 5. Reload Asterisk & FreePBX core
echo "[*] Reloading Asterisk and Web Interface..."
asterisk -rx "core reload"
/var/lib/asterisk/bin/module_admin reload > /dev/null 2>&1

echo "======================================================"
echo "  Setup Completed Successfully!                       "
echo "======================================================"
