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

# 2. استخراج یوزر و پسورد دیتابیس از extensions_additional.conf
EXT_ADDITIONAL="/etc/asterisk/extensions_additional.conf"

if [ ! -f "$EXT_ADDITIONAL" ]; then
    echo "[-] Error: $EXT_ADDITIONAL not found!"
    exit 1
fi

# پیدا کردن مقادیر با حذف فاصله‌ها و کاراکترهای اضافی
DBUSER=$(grep -w "^AMPDBUSER" "$EXT_ADDITIONAL" | cut -d= -f2 | tr -d ' ' | tr -d '\r')
DBPASS=$(grep -w "^AMPDBPASS" "$EXT_ADDITIONAL" | cut -d= -f2 | tr -d ' ' | tr -d '\r')

if [ -z "$DBUSER" ] || [ -z "$DBPASS" ]; then
    echo "[-] Error: Could not extract DBUSER or DBPASS from $EXT_ADDITIONAL."
    echo "    Make sure the [globals] section contains AMPDBUSER and AMPDBPASS."
    exit 1
fi

echo "[+] Credentials extracted successfully."
echo ""

# 3. دریافت لیست ترانک‌ها از دیتابیس و نمایش به کاربر
echo "[*] Fetching Trunks from Database..."
echo "------------------------------------------------------------"
mysql -u"$DBUSER" -p"$DBPASS" -e "SELECT trunkid, name, channelid FROM asterisk.trunks;"
echo "------------------------------------------------------------"
echo ""

# 4. دریافت نام ترانک از کاربر
read -p "Enter the 'name' of the Trunk you want to apply tafreshicid context: " TRUNK_NAME

if [ -z "$TRUNK_NAME" ]; then
    echo "[-] Error: Trunk name cannot be empty. Exiting."
    exit 1
fi

# 5. به‌روزرسانی کانتکست ترانک در دیتابیس
echo "[*] Updating Trunk '$TRUNK_NAME' context to 'tafreshicid'..."
mysql -u"$DBUSER" -p"$DBPASS" -e "UPDATE asterisk.trunks SET context='tafreshicid' WHERE name='$TRUNK_NAME';"

# بررسی موفقیت‌آمیز بودن کوئری
if [ $? -eq 0 ]; then
    echo "[+] Trunk updated successfully in database."
else
    echo "[-] Error: Database update failed."
    exit 1
fi

# 6. اعمال تغییرات در استریسک و وب سرویس
echo "[*] Applying changes to Asterisk..."
# آپدیت سیستم فری‌پی‌بی‌اکس تا تنظیمات جدید را بنویسد
asterisk -rx "core reload" > /dev/null 2>&1
# برای اطمینان از اعمال تغییرات در دیتابیس ایزابل/FreePBX، نیاز به ریلود ماژول‌هاست
/var/lib/asterisk/bin/module_admin reload > /dev/null 2>&1

echo "[+] Asterisk reloaded successfully."
echo ""
echo "============================================================"
echo "    Installation & Setup Completed Successfully!            "
echo "============================================================"
