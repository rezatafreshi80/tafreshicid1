#!/bin/bash

echo "============================================================"
echo "    Tafreshi CID Module Installer for Issabel / Asterisk"
echo "    Company: Ertebat Center (ertebatcenter.com)"
echo "============================================================"

# 1. Inject Context
CUSTOM_CONF="/etc/asterisk/extensions_custom.conf"
if grep -q "\[tafreshicid\]" "$CUSTOM_CONF"; then
    echo "[*] Context [tafreshicid] already exists in $CUSTOM_CONF. Skipping injection."
else
    echo "[*] Injecting [tafreshicid] into $CUSTOM_CONF..."
    cat <<EOF >> "$CUSTOM_CONF"

[tafreshicid]
exten => _X.,1,NoOp(Tafreshi CID Normalization)
exten => _X.,n,Set(CALLERID(num)=0\${CALLERID(num):-10})
exten => _X.,n,Goto(from-trunk,\${EXTEN},1)
EOF
fi

# 2. Extract DB Credentials
echo "[*] Extracting Database credentials from amportal.conf..."
DB_USER=$(grep -E "^AMPDBUSER" /etc/amportal.conf | cut -d'=' -f2 | tr -d ' ' | tr -d '"')
DB_PASS=$(grep -E "^AMPDBPASS" /etc/amportal.conf | cut -d'=' -f2 | tr -d ' ' | tr -d '"')

if [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
    echo "[-] Error: Could not extract DB credentials."
    exit 1
fi
echo "[+] Credentials extracted successfully."

# 3. Fetch Trunks
echo "[*] Fetching Trunks from Database..."
mysql -u"$DB_USER" -p"$DB_PASS" asterisk -e "SELECT trunkid, name, channelid FROM trunks;"

read -p "Enter the 'name' of the Trunk you want to apply tafreshicid context: " TRUNK_NAME

# 4. Get Channel ID
TRUNK_CHANNELID=$(mysql -u"$DB_USER" -p"$DB_PASS" asterisk -sN -e "SELECT channelid FROM trunks WHERE name='$TRUNK_NAME';")

if [ -z "$TRUNK_CHANNELID" ]; then
    echo "[-] Error: Trunk '$TRUNK_NAME' not found."
    exit 1
fi

# 5. Update Context in sip and pjsip tables
echo "[*] Updating Trunk '$TRUNK_NAME' (Channel ID: $TRUNK_CHANNELID) context to 'tafreshicid'..."

# Update SIP table
mysql -u"$DB_USER" -p"$DB_PASS" asterisk -e "UPDATE sip SET data='tafreshicid' WHERE id='$TRUNK_CHANNELID' AND keyword='context';"
# Update PJSIP table (if applicable)
mysql -u"$DB_USER" -p"$DB_PASS" asterisk -e "UPDATE pjsip SET data='tafreshicid' WHERE id='$TRUNK_CHANNELID' AND keyword='context';"

# 6. Apply Changes
echo "[*] Reloading Asterisk and Issabel modules..."
asterisk -rx "core reload"
/var/lib/asterisk/bin/module_admin reload

echo "[+] Installation and configuration completed successfully!"
