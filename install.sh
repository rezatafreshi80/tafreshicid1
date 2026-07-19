#!/bin/bash

echo "======================================"
echo "   Tafreshi CID Normalization Setup   "
echo "======================================"
echo "در حال جستجوی ترانک‌های SIP..."

# استخراج نام ترانک‌ها از فایل کانفیگ بدون لمس دیتابیس
# به دنبال بلوک‌هایی می‌گردیم که کانتکست آن‌ها از نوع ترانک است
TRUNK_LIST=($(awk -F'[][]' '/^\[/ {sec=$2} /context=from-trunk|context=from-pstn/ {print sec}' /etc/asterisk/sip_additional.conf | sort | uniq))

if [ ${#TRUNK_LIST[@]} -eq 0 ]; then
    echo "هیچ ترانکی به صورت خودکار یافت نشد!"
    read -p "لطفاً نام ترانک (Trunk Name) را به صورت دستی وارد کنید: " SELECTED_TRUNK
else
    echo "لطفاً ترانک مورد نظر خود را از لیست زیر انتخاب کنید:"
    
    # ایجاد منوی انتخابی (1 تا 9)
    PS3="شماره ترانک را وارد کنید: "
    select TRUNK in "${TRUNK_LIST[@]}" "وارد کردن دستی (Manual)"; do
        if [ "$TRUNK" == "وارد کردن دستی (Manual)" ]; then
            read -p "نام ترانک را دستی وارد کنید: " SELECTED_TRUNK
            break
        elif [ -n "$TRUNK" ]; then
            SELECTED_TRUNK=$TRUNK
            break
        else
            echo "انتخاب نامعتبر است. لطفاً یک عدد صحیح وارد کنید."
        fi
    done
fi

echo "ترانک انتخاب شده: $SELECTED_TRUNK"

# ادامه اسکریپت و نوشتن در sip_custom_post.conf
CUSTOM_POST_FILE="/etc/asterisk/sip_custom_post.conf"

# بررسی اینکه آیا این ترانک قبلاً اضافه شده یا خیر
if grep -q "\[$SELECTED_TRUNK\](+)" "$CUSTOM_POST_FILE"; then
    echo "هشدار: تنظیمات برای این ترانک قبلاً در $CUSTOM_POST_FILE اعمال شده است!"
else
    echo "" >> "$CUSTOM_POST_FILE"
    echo "[$SELECTED_TRUNK](+)" >> "$CUSTOM_POST_FILE"
    echo "context=tafreshicid" >> "$CUSTOM_POST_FILE"
    echo "تنظیمات با موفقیت در sip_custom_post.conf درج شد (Override امن)."
fi

# Reload Asterisk Dialplan
echo "در حال اعمال تغییرات در استریسک..."
asterisk -rx "dialplan reload"
asterisk -rx "sip reload"
echo "عملیات با موفقیت به پایان رسید."
