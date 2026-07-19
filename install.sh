#!/bin/bash

echo "============================================================"
echo "    Tafreshi CID Module Installer (Zero-Touch & Safe)"
echo "    Company: Ertebat Center (ertebatcenter.com)"
echo "============================================================"

CUSTOM_CONF="/etc/asterisk/extensions_custom.conf"
SIP_ADDITIONAL="/etc/asterisk/sip_additional.conf"
SIP_CUSTOM_POST="/etc/asterisk/sip_custom_post.conf"
CONTEXT_NAME="tafreshicid"

echo "[*] Step 1: Injecting '$CONTEXT_NAME' context into $CUSTOM_CONF..."

# بررسی و افزودن کانتکست اصلاحی بدون دستکاری فایل‌های اصلی
if ! grep -q "\[$CONTEXT_NAME\]" "$CUSTOM_CONF"; then
    cat << EOF >> "$CUSTOM_CONF"

[$CONTEXT_NAME]
exten => _X.,1,NoOp(Tafreshi CID Normalization)
exten => _X.,n,Set(CALLERID(num)=0\${CALLERID(num):-10})
exten => _X.,n,Goto(from-trunk,\${EXTEN},1)
EOF
    echo "[+] Context '$CONTEXT_NAME' added successfully."
else
    echo "[-] Context '$CONTEXT_NAME' already exists. Skipping."
fi

echo "[*] Step 2: Auto-detecting Trunks and applying Safe Overrides..."

# پیدا کردن ترانک‌ها از sip_additional و تزریق به sip_custom_post با ویژگی (+)
if [ -f "$SIP_ADDITIONAL" ]; then
    # استخراج نام ترانک‌هایی که کانتکست from-trunk یا from-pstn دارند
    TRUNKS=$(grep -E '\[.*\]' "$SIP_ADDITIONAL" | grep -v 'general' | tr -d '[]')
    
    if [ -z "$TRUNKS" ]; then
        echo "[!] No standard SIP trunks found."
    else
        for TRUNK in $TRUNKS; do
            # بررسی اینکه آیا قبلاً این ترانک اورراید شده یا خیر
            if ! grep -q "\[$TRUNK\](+)" "$SIP_CUSTOM_POST" 2>/dev/null; then
                echo -e "\n[$TRUNK](+)\ncontext=$CONTEXT_NAME" >> "$SIP_CUSTOM_POST"
                echo "[+] Trunk [$TRUNK] overridden safely."
            else
                echo "[-] Trunk [$TRUNK] already configured. Skipping."
            fi
        done
    fi
else
    echo "[!] $SIP_ADDITIONAL not found. Make sure trunks are configured in GUI first."
fi

echo "[*] Step 3: Reloading Asterisk Modules safely..."
asterisk -rx "dialplan reload"
asterisk -rx "sip reload"

echo "======================================================"
echo "  Setup Completed Successfully! No DB changes made.   "
echo "======================================================"
