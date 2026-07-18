#!/bin/bash

echo "=================================================="
echo "  Tafreshi CallerID Normalization Installer"
echo "=================================================="

# بخش اول: اضافه کردن کانتکست به فایل استریسک
echo "[1/5] Injecting [tafreshicid] context into extensions_custom.conf..."
if ! grep -q "\[tafreshicid\]" /etc/asterisk/extensions_custom.conf; then
    cat << 'EOF' >> /etc/asterisk/extensions_custom.conf

[tafreshicid]
exten => _X.,1,NoOp(--- Tafreshi CID Normalization ---)
exten => _X.,n,Set(CALLERID(num)=${FILTER(0-9,${CALLERID(num)})})
exten => _X.,n,ExecIf($["${CALLERID(num):0:3}" = "098"]?Set(CALLERID(num)=0${CALLERID(num):3}))
exten => _X.,n,ExecIf($["${CALLERID(num):0:2}" = "98"]?Set(CALLERID(num)=0${CALLERID(num):2}))
exten => _X.,n,ExecIf($["${CALLERID(num):0:3}" = "021"]?Set(CALLERID(num)=${CALLERID(num):3}))
exten => _X.,n,ExecIf($["${CALLERID(num):0:2}" = "21"]?Set(CALLERID(num)=${CALLERID(num):2}))
exten => _X.,n,Goto(from-trunk,${EXTEN},1)
EOF
    echo "Context added successfully."
else
    echo "Context [tafreshicid] already exists."
fi

# بخش دوم: خواندن خودکار اطلاعات دیتابیس از ایزابل
echo ""
echo "[2/5] Auto-detecting Database Configuration..."
DB_USER="root"
DB_PASS=$(grep -w "mysqlrootpwd" /etc/issabel.conf | cut -d'=' -f2)

if [ -z "$DB_PASS" ]; then
    echo "Error: Could not find database password in /etc/issabel.conf!"
    exit 1
fi
echo "Database credentials loaded automatically."

# بخش سوم: استخراج لیست ترانک‌ها از دیتابیس
echo "[3/5] Fetching SIP Trunks from database..."
TRUNK_LIST=$(mysql -u"$DB_USER" -p"$DB_PASS" asterisk -N -B -e "SELECT name FROM sip WHERE keyword='host' GROUP BY name;" 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "Error: Database connection failed! Please check MariaDB status."
    exit 1
fi

if [ -z "$TRUNK_LIST" ]; then
    echo "Error: No SIP trunks found in the database!"
    exit 1
fi

# بخش چهارم: نمایش ترانک‌ها و انتخاب توسط کاربر
echo "[4/5] Available SIP Trunks:"
TRUNKS=($TRUNK_LIST)
for i in "${!TRUNKS[@]}"; do
    echo "$((i+1)). ${TRUNKS[$i]}"
done

echo ""
read -p "Select the trunk number to apply [tafreshicid] context: " TRUNK_NUM

if ! [[ "$TRUNK_NUM" =~ ^[0-9]+$ ]] || [ "$TRUNK_NUM" -lt 1 ] || [ "$TRUNK_NUM" -gt "${#TRUNKS[@]}" ]; then
    echo "Invalid selection. Installation aborted."
    exit 1
fi

SELECTED_TRUNK="${TRUNKS[$((TRUNK_NUM-1))]}"
echo "You selected: $SELECTED_TRUNK"

# بخش پنجم: اعمال تغییرات در دیتابیس و ری‌استارت استریسک
echo "[5/5] Updating trunk context in database and reloading Asterisk..."
mysql -u"$DB_USER" -p"$DB_PASS" asterisk -e "UPDATE sip SET data='tafreshicid' WHERE name='$SELECTED_TRUNK' AND keyword='context';"

asterisk -rx "dialplan reload"
asterisk -rx "core reload"

echo "=================================================="
echo "  Installation Completed Successfully!"
echo "=================================================="
