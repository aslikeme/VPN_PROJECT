#! /bin/bash
set -e
# Outputs an error (in STDERR) and terminates the script
# if the script is run without superuser rights
(( EUID != 0 )) && { echo 'The script needs superuser rights.' >&2; exit 1; }

echo ************* НАСТРОЙКА И СИНХРОНИЗАЦИЯ ВРЕМЕНИ *************
# синхронизация времени по определенному часовому поясу всех машин
timedatectl set-timezone Europe/Moscow
systemctl restart systemd-timesyncd.service 

# настройка ssh
echo ************* НАСТРОЙКА SSH *************
sed -i 's/#\?\(PermitRootLogin\s*\).*$/\1 no/' /etc/ssh/sshd_config
sed -i 's/#\?\(PubkeyAuthentication\s*\).*$/\1 yes/' /etc/ssh/sshd_config
sed -i 's/#\?\(PermitEmptyPasswords\s*\).*$/\1 no/' /etc/ssh/sshd_config
sed -i 's/#\?\(PasswordAuthentication\s*\).*$/\1 no/' /etc/ssh/sshd_config

cat <<EOF>> /etc/ssh/ssh_config
StrictHostKeyChecking accept-new
EOF
echo ************* ВЫПОЛНЕННО *************

read -p "Введите имя текущего пользователя: " bckpUser
read -p "Введите имя пользователя удостоверяющего центра: " caUser
read -p "Введите IP-адрес удостоверяющего центра: " caIp  # адрес машины удостоверяющего центра в сети


echo ************* УСТАНОВКА НЕОБХОДИМЫХ ПАКЕТОВ *************
# установка необходимых пакетов
apt update &&  apt install -y prometheus-node-exporter iptables apache2-utils 		|| { echo "Установка пакетов не удалась!"; exit 1; }

echo ************* УСТАНОВКА ПРАВИЛ IPtables *************
chmod +x /home/$bckpUser/artefacts/*.sh
bash /home/$bckpUser/artefacts/bkpIPtablesRules.sh

echo ************* СОЗДАНИЕ ДИРИКТОРИЯ ДЛЯ ХРАНЕНИЯ РЕЗЕРВНЫХ КОПИЙ *************
if [ ! -d /home/$bckpUser/backup/vpn ]; then
  mkdir -p /home/$bckpUser/backup/vpn;
fi

if [ ! -d /home/$bckpUser/backup/ca ]; then
  mkdir  -p /home/$bckpUser/backup/ca;
fi

if [ ! -d /home/$bckpUser/backup/monitoring ]; then
  mkdir  -p /home/$bckpUser/backup/monitoring;
fi

chown -R $bckpUser:$bckpUser /home/$bckpUser/backup/
echo ************* ВЫПОЛНЕННО *************

echo ************* ПОСТАНОВКА ЗАДАЧ ЗАПУСКА РЕЗЕРВНОГО КОПИРОВАНИЯ ПО ВРЕМЕНИ *************
##### создание задачи в cron  ####
cat <<EOF> /etc/cron.d/rsync_bkup

0 22 * * 1 $bckpUser /home/$bckpUser/artefacts/rsync_to_cron_ca.sh
5 22 * * 1 $bckpUser /home/$bckpUser/artefacts/rsync_to_cron_vpn.sh
10 22 * * 1 $bckpUser /home/$bckpUser/artefacts/rsync_to_cron_monitor.sh
EOF
echo ************* ВЫПОЛНЕННО *************

echo ************* НАСТРОЙКА И ЗАПУСК ЭКСПОРТЕРОВ ДЛЯ МОНИТОРИНГА *************
### node exporter ###
read -p "Введите DNS-адрес машины №1 резервного копирования: " bkp2Addr

#создадим рабочий каталог для node_exporter
if [ ! -d /opt/node_exporter ]; then
  mkdir  /opt/node_exporter;
fi

scp -i /home/$bckpUser/.ssh/id_rsa $caUser@$caIp:~/easy-rsa/pki/issued/$bkp2Addr.crt /opt/node_exporter/ || { echo "Что-то пошло не так! Копирование не удалось!"; exit 1; } # перенос сертификата для сервера node_exporter на bkp1-машине
scp -i /home/$bckpUser/.ssh/id_rsa $caUser@$caIp:~/easy-rsa/pki/private/$bkp2Addr.key /opt/node_exporter/ || { echo "Что-то пошло не так! Копирование не удалось!"; exit 1; } # перенос ключа сервера node_exporter на bkp1-машине
scp -i /home/$bckpUser/.ssh/id_rsa $caUser@$caIp:~/easy-rsa/pki/ca.crt /opt/node_exporter/ 		|| { echo "Что-то пошло не так! Копирование не удалось!"; exit 1; }  # перенос сертификата для нод экспортера

chmod 640 /opt/node_exporter/*.key
chmod 640 /opt/node_exporter/*.crt
chown -R prometheus:prometheus /opt/node_exporter/

# запросим данные для авторизации и запишем их в конфигурационный файл
    read -p "Node Exporter username: " username
    read -p "Node Exporter password: " -s password
    echo -e "tls_server_config:\n  cert_file: $bkp2Addr.crt \n  key_file: $bkp2Addr.key \n  client_auth_type: "RequireAndVerifyClientCert" \n  client_ca_file: ca.crt \n\nbasic_auth_users:\n  $username: '$(htpasswd -nbB -C 10 admin "$password" | grep -o "\$.*")'" >/opt/node_exporter/web.yml


cat <<EOF> /etc/systemd/system/multi-user.target.wants/prometheus-node-exporter.service
[Unit]
Description=Prometheus exporter for machine metrics
Documentation=https://github.com/prometheus/node_exporter

[Service]
Restart=on-failure
User=prometheus
EnvironmentFile=/etc/default/prometheus-node-exporter
ExecStart=/usr/bin/prometheus-node-exporter $ARGS --web.config=/opt/node_exporter/web.yml
ExecReload=/bin/kill -HUP $MAINPID
TimeoutStopSec=20s
SendSIGKILL=no

[Install]
WantedBy=multi-user.target

EOF

# перезагрузим сервисы prometheus
systemctl daemon-reload
systemctl restart prometheus-node-exporter.service
echo ************* ВЫПОЛНЕННО *************
