#!/bin/bash

echo "============================================================"
echo "    Tafreshi CID Module Installer for Issabel / Asterisk    "
echo "    Company: Ertebat Center (ertebatcenter.com)             "
echo "============================================================"
echo ""

# 1. افزودن کانتکست به extensions_custom.conf
CUSTOM_CONF="/etc/asterisk/extensions_custom.conf"
CONTEXT_NAME="[tafreshicid]"

if grep -qF "$CONTEXT_NAME" "$CUSTOM_CONF"; then
    echo "[*] Context $CONTEXT_NAME already exists in $CUSTOM_CONF. Skipping injection."
else
    echo "[*] Injecting $CONTEXT_NAME into $CUSTOM_CONF..."
    cat <<EOF >> "$CUSTOM_CONF"

$CONTEXT_NAME
exten => _X.,1,NoOp(Tafreshi CID Normalization)
exten => _X.,n,Set(CALLERID(num)=0\${CALLERID(num)})
exten => _X.,n,Goto(from-trunk,\${EXTEN},1)
EOF
    echo "[+] Context injected successfully."
fi

echo ""
echo "[*] Extracting Database credentials from extensions_additional.conf..."

# 2. استخراج یوزر و پسورد دیتابیس
EXT_ADDITIONAL="/etc/asterisk/extensions_additional.conf"

if [ ! -f "$EXT_ADDITIONAL" ]; then
    echo "[-] Error: $EXT_ADDITIONAL not found!"
    exit 1
fi

DBUSER=$(grep -w "^AMPDBUSER" "$EXT_ADDITIONAL" | cut -d= -f2 | tr -d ' ' | tr -d '\r')
DBPASS=$(grep -w "^AMPDBPASS" "$EXT_ADDITIONAL" | cut -d= -f2 | tr -d ' ' | tr -d '\r')

if [ -z "$DBUSER" ] || [ -z "$DBPASS" ]; then
    echo "[-] Error: Could not extract DBUSER or DBPASS."
    exit 1
fi

echo "[+] Credentials extracted successfully."
echo ""

# 3. دریافت لیست ترانک‌ها
echo "[*] Fetching Trunks from Database..."
echo "------------------------------------------------------------"
mysql -u"$DBUSER" -p"$DBPASS" -e "SELECT trunkid, name, channelid FROM asterisk.trunks;"
echo "------------------------------------------------------------"
echo ""

# 4. دریافت نام ترانک
read -p "Enter the 'name' of the Trunk you want to apply tafreshicid context: " TRUNK_NAME

if [ -z "$TRUNK_NAME" ]; then
    echo "[-] Error: Trunk name cannot be empty. Exiting."
    exit 1
fi

# 5. پیدا کردن Channel ID و آپدیت کانتکست در جداول SIP/PJSIP/IAX
echo "[*] Updating Trunk '$TRUNK_NAME' context to 'tafreshicid'..."

# استخراج channelid برای پیدا کردن رکورد در جداول sip/pjsip
CHANNEL_ID=$(mysql -u"$DBUSER" -p"$DBPASS" -sN -e "SELECT channelid FROM asterisk.trunks WHERE name='$TRUNK_NAME' LIMIT 1;")

if [ -z "$CHANNEL_ID" ]; then
    echo "[-] Error: Could not find Trunk '$TRUNK_NAME' in asterisk.trunks."
    exit 1
fi

# آپدیت کانتکست در جداول مرتبط (خطاهای احتمالی به dev/null ارسال می‌شوند تا در صورت عدم استفاده از یک پروتکل خطایی چاپ نشود)
mysql -u"$DBUSER" -p"$DBPASS" -e "UPDATE asterisk.sip SET data='tafreshicid' WHERE id='$CHANNEL_ID' AND keyword='context';" 2>/dev/null
mysql -u"$DBUSER" -p"$DBPASS" -e "UPDATE asterisk.pjsip SET data='tafreshicid' WHERE id='$CHANNEL_ID' AND keyword='context';" 2>/dev/null
mysql -u"$DBUSER" -p"$DBPASS" -e "UPDATE asterisk.iax SET data='tafreshicid' WHERE id='$CHANNEL_ID' AND keyword='context';" 2>/dev/null

echo "[+] Trunk context updated successfully in database."

# 6. اعمال تغییرات
echo "[*] Applying changes to Asterisk..."
asterisk -rx "core reload" > /dev/null 2>&1
/var/lib/asterisk/bin/module_admin reload > /dev/null 2>&1

echo "[+] Asterisk reloaded successfully."
echo ""
echo "============================================================"
echo "    Installation & Setup Completed Successfully!            "
echo "============================================================"
