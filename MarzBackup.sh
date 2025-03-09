#!/bin/bash

echo -e "\nMarzBackup: AC Backup but simply better. Made exclusively for Marzban.\n"
echo -e "\nCAUTION: MarzBackup is not meant to be used in production. Use it at your own risk.\n"
# Bot token
# گرفتن توکن ربات از کاربر و ذخیره آن در متغیر tk
while [[ -z "$tk" ]]; do
    echo "Enter Your backup bot token: "
    read -r tk
    if [[ $tk == $'\0' ]]; then
        echo "Invalid input. Token cannot be empty."
        unset tk
    fi
done

# Chat id
# گرفتن Chat ID از کاربر و ذخیره آن در متغیر chatid
while [[ -z "$chatid" ]]; do
    echo "Enter Your TG account's chatID: "
    read -r chatid
    if [[ $chatid == $'\0' ]]; then
        echo "Invalid input. Chat ID cannot be empty."
        unset chatid
    elif [[ ! $chatid =~ ^\-?[0-9]+$ ]]; then
        echo "${chatid} is not a number."
        unset chatid
    fi
done

# Caption
# گرفتن عنوان برای فایل پشتیبان و ذخیره آن در متغیر caption
echo "Caption (for example your domain to identify the database file more easily): "
read -r caption

# Cronjob
# تعیین زمانی برای اجرای این اسکریپت به صورت دوره‌ای
while true; do
    echo "Cronjob (minutes and hours) (e.g : 30 6 or 0 12) : "
    read -r minute hour
    if [[ $minute == 0 ]] && [[ $hour == 0 ]]; then
        cron_time="* * * * *"
        break
    elif [[ $minute == 0 ]] && [[ $hour =~ ^[0-9]+$ ]] && [[ $hour -lt 24 ]]; then
        cron_time="0 */${hour} * * *"
        break
    elif [[ $hour == 0 ]] && [[ $minute =~ ^[0-9]+$ ]] && [[ $minute -lt 60 ]]; then
        cron_time="*/${minute} * * * *"
        break
    elif [[ $minute =~ ^[0-9]+$ ]] && [[ $hour =~ ^[0-9]+$ ]] && [[ $hour -lt 24 ]] && [[ $minute -lt 60 ]]; then
        cron_time="*/${minute} */${hour} * * *"
        break
    else
        echo "Invalid input, please enter a valid cronjob format (minutes and hours, e.g: 0 6 or 30 12)"
    fi
done


# Acknowledge
while [[ -z "$xmh" ]]; do
    echo "Enter m to acknowledge that you understand this is an EXPERIMENTAL backup script ONLY INTENDED FOR MARZBAN: "
    read -r xmh
    if [[ $xmh == $'\0' ]]; then
        echo "Invalid input. Please enter m to acknowledge."
        unset xmh
    elif [[ ! $xmh =~ ^[m]$ ]]; then
        echo "${xmh} is not a valid option. Please enter m to acknowledge."
        unset xmh
    fi
done

# get password
while [[ -z "$pass" ]]; do
    echo "Enter backup file(7z) password: "
    read -r pass
    if [[ $pass == $'\0' ]]; then
        echo "Invalid input. Password cannot be empty. Use vanilla ac backup if you don't want to encrypt your backups"
        unset pass
    fi
done

while [[ -z "$crontabs" ]]; do
    echo "Would you like to delete all marzbackup/acbackup crontabs(if present)? [y/n] : "
    read -r crontabs
    if [[ $crontabs == $'\0' ]]; then
        echo "Invalid input. Please choose y or n."
        unset crontabs
    elif [[ ! $crontabs =~ ^[yn]$ ]]; then
        echo "${crontabs} is not a valid option. Please choose y or n."
        unset crontabs
    fi
done

if [[ "$crontabs" == "y" ]]; then
# remove cronjobs
sudo crontab -l | grep -vE '/root/ac-backup.+\.sh|/root/marzbackup/marzbackup.sh' | sudo crontab -
fi


# m backup
if [[ "$xmh" == "m" ]]; then

if dir=$(find /opt /root -type d -iname "marzban" -print -quit); then
  echo "Found Marzban's directory. it exists at $dir"
else
  echo "Couldn't find Marzban's directory. terminating."
  exit 1
fi

if [ -d "/var/lib/marzban/mysql" ]; then

  sed -i -e 's/\s*=\s*/=/' -e 's/\s*:\s*/:/' -e 's/^\s*//' /opt/marzban/.env

  docker exec marzban-mysql-1 bash -c "mkdir -p /var/lib/mysql/db-backup"
  source /opt/marzban/.env

    cat > "/var/lib/marzban/mysql/ac-backup.sh" <<EOL
#!/bin/bash

USER="root"
PASSWORD="$MYSQL_ROOT_PASSWORD"


databases=\$(mysql -h 127.0.0.1 --user=\$USER --password=\$PASSWORD -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)

for db in \$databases; do
    if [[ "\$db" != "information_schema" ]] && [[ "\$db" != "mysql" ]] && [[ "\$db" != "performance_schema" ]] && [[ "\$db" != "sys" ]] ; then
        echo "Dumping database: \$db"
		mysqldump -h 127.0.0.1 --force --opt --user=\$USER --password=\$PASSWORD --databases \$db > /var/lib/mysql/db-backup/\$db.sql

    fi
done

EOL
chmod +x /var/lib/marzban/mysql/ac-backup.sh

sz=$(cat <<EOF
docker exec marzban-mysql-1 bash -c "/var/lib/mysql/ac-backup.sh"
mkdir /root/marzbackup >/dev/null 2>&1
rm /root/marzbackup/crontabbackup.txt  >/dev/null 2>&1
crontab -l > /root/marzbackup/crontabbackup.txt
cp -r /var/lib/marzban/mysql/db-backup /root/marzbackup/
7z a -p"$pass" -mhe=on -t7z -m0=lzma2 /root/marzbackup/MarzbanBackup.7z /etc/wireguard/* /opt/marzban/* /opt/marzban/.env /var/lib/marzban/* /root/marzbackup/db-backup/* /etc/nginx /etc/haproxy /etc/sysctl.conf -x\!/var/lib/marzban/mysql 
rm -rf /var/lib/marzban/mysql/db-backup/* 
rm -rf /root/marzbackup/db-backup
EOF
)

    else
      sz=$(cat <<EOF
mkdir /root/marzbackup  >/dev/null 2>&1
rm /root/marzbackup/crontabbackup.txt  >/dev/null 2>&1
crontab -l > /root/marzbackup/crontabbackup.txt
7z a -p"$pass" -mhe=on -t7z -m0=lzma2 /root/marzbackup/MarzbanBackup.7z /etc/wireguard/* /opt/marzban/* /opt/marzban/.env /var/lib/marzban/* /etc/nginx /etc/haproxy /etc/sysctl.conf
EOF
)
fi

marzbackup="Marzban extended backup by MarzBackup"

else
echo "Please enter m to acknowledge "
exit 1
fi


trim() {
    # remove leading and trailing whitespace/lines
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

IP=$(ip route get 1 | sed -n 's/^.*src \([0-9.]*\) .*$/\1/p')
caption="${caption}\n\n${marzbackup}\n<code>${IP}</code>"
comment=$(echo -e "$caption" | sed 's/<code>//g;s/<\/code>//g')
comment=$(trim "$comment")

# install 7z
sudo apt install p7zip-full -y

# make dir for marzbackup
mkdir /root/marzbackup  >/dev/null 2>&1

# send backup to telegram
# ارسال فایل پشتیبانی به تلگرام
cat > "/root/marzbackup/marzbackup.sh" <<EOL
rm -rf /root/marzbackup/MarzbanBackup.7z
$sz
curl -F chat_id="${chatid}" -F caption=\$'${caption}' -F parse_mode="HTML" -F document=@"/root/marzbackup/MarzbanBackup.7z" https://api.telegram.org/bot${tk}/sendDocument
EOL


# Add cronjob
# افزودن کرانجاب جدید برای اجرای دوره‌ای این اسکریپت
{ crontab -l -u root; echo "${cron_time} /bin/bash /root/marzbackup/marzbackup.sh >/dev/null 2>&1"; } | crontab -u root -

# run the script
# اجرای این اسکریپت
bash "/root/marzbackup/marzbackup.sh"

# Done
# پایان اجرای اسکریپت
echo -e "\nDone!\n"
echo -e "\nThank you for using MarzBackup!\n"
echo -e "\nPlease consider giving MarzBackup a star if you found it useful.\n"
echo -e "\ngithub.com/Ferixy/marzbackup\n"
