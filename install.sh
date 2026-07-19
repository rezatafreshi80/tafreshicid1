#!/bin/bash

echo "=========================================="
echo "    Tafreshi CallerID Normalization       "
echo "=========================================="

# 1. Ask for Trunk Name
read -p "Please enter the Trunk Name (e.g., Trunk_Shatel): " TRUNK_NAME

if [ -z "$TRUNK_NAME" ]; then
    echo "Error: Trunk name cannot be empty. Exiting..."
    exit 1
fi

# 2. Inject Dialplan into extensions_custom.conf if not exists
if ! grep -q "\[tafreshicid\]" /etc/asterisk/extensions_custom.conf; then
    echo "" >> /etc/asterisk/extensions_custom.conf
    echo "[tafreshicid]" >> /etc/asterisk/extensions_custom.conf
    echo "exten => _X.,1,NoOp(Fixing CallerID by Tafreshi)" >> /etc/asterisk/extensions_custom.conf
    echo "exten => _X.,n,Set(CALLERID(num)=0\${CALLERID(num)})" >> /etc/asterisk/extensions_custom.conf
    echo "exten => _X.,n,Goto(from-trunk,\${EXTEN},1)" >> /etc/asterisk/extensions_custom.conf
    echo "Dialplan context [tafreshicid] added."
else
    echo "Dialplan context [tafreshicid] already exists."
fi

# 3. Override Trunk Context in sip_custom_post.conf
if ! grep -q "\[$TRUNK_NAME\](+)" /etc/asterisk/sip_custom_post.conf; then
    echo "" >> /etc/asterisk/sip_custom_post.conf
    echo "[$TRUNK_NAME](+)" >> /etc/asterisk/sip_custom_post.conf
    echo "context=tafreshicid" >> /etc/asterisk/sip_custom_post.conf
    echo "Context for trunk [$TRUNK_NAME] successfully updated."
else
    echo "Warning: Trunk [$TRUNK_NAME] is already modified in sip_custom_post.conf"
fi

# 4. Reload Asterisk configurations
echo "Reloading Asterisk..."
asterisk -rx "dialplan reload"
asterisk -rx "sip reload"

echo "=========================================="
echo "        Installation Completed!           "
echo "=========================================="
