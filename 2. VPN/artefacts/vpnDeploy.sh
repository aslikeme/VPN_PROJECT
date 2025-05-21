#! /bin/bash
set -e
# Outputs an error (in STDERR) and terminates the script
# if the script is run without superuser rights
(( EUID != 0 )) && { echo 'The script needs superuser rights.' >&2; exit 1; }

echo -e "\n ************* НАСТРОЙКА И СИНХРОНИЗАЦИЯ ВРЕМЕНИ ************* \n"
# синхронизация времени по определенному часовому поясу всех машин
timedatectl set-timezone Europe/Moscow
systemctl restart systemd-timesyncd.service 

echo -e "\n ************* НАСТРОЙКА SSH ************* \n"
# настройка ssh
sed -i 's/#\?\(PermitRootLogin\s*\).*$/\1 no/' /etc/ssh/sshd_config
sed -i 's/#\?\(PubkeyAuthentication\s*\).*$/\1 yes/' /etc/ssh/sshd_config
sed -i 's/#\?\(PermitEmptyPasswords\s*\).*$/\1 no/' /etc/ssh/sshd_config
sed -i 's/#\?\(PasswordAuthentication\s*\).*$/\1 no/' /etc/ssh/sshd_config

cat <<EOF>> /etc/ssh/ssh_config
StrictHostKeyChecking accept-new
EOF
echo -e "\n ************* ВЫПОЛНЕННО ************* \n"

echo -e "\n ************* УСТАНОВКА НЕОБХОДИМЫХ ПАКЕТОВ ************* \n"
apt update && apt install -y openvpn prometheus-node-exporter iptables apache2-utils		|| { echo "Установка пакетов не удалась!"; exit 1; }
echo -e "\n ************* ВЫПОЛНЕННО ************* \n"

read -p "Введите имя пользователя VPN-сервера: " vpnUser
read -p "Введите имя пользователя удостоверяющего центра: " caUser
read -p "Введите IP-адрес удостоверяющего центра: " caIp  # адрес машины удостоверяющего центра в сети

echo -e "\n ************* УСТАНОВКА ПРАВИЛ IPtables ************* \n"
bash /home/$vpnUser/artefacts/vpnIPtablesRules.sh                                               || { echo "Что-то пошло не так! Настройка фаервола не удалась!"; exit 1; }
echo -e "\n ************* ВЫПОЛНЕННО ************* \n"

echo -e "\n************* ПЕРЕНОС КЛЮЧЕЙ И СЕРТИФИКАТОВ И ЗАПУСК OPENVPN-СЕРВЕРА  ************* \n"
scp -i /home/$vpnUser/.ssh/id_rsa $caUser@$caIp:~/easy-rsa/pki/ca.crt /home/$vpnUser/ 		|| { echo "Что-то пошло не так! Копирование не удалось!"; exit 1; }  # перенос сертификатов на сервер впн
scp -i /home/$vpnUser/.ssh/id_rsa $caUser@$caIp:~/easy-rsa/pki/issued/server.crt /home/$vpnUser/|| { echo "Что-то пошло не так! Копирование не удалось!"; exit 1; } # перенос сертификатов на сервер впн
cp /home/$vpnUser/ca.crt /etc/openvpn/server/ 							|| { echo "Ошибка! Перемещение не удалось!" ; exit 1; }
mv /home/$vpnUser/server.crt /etc/openvpn/server/ 						|| { echo "Ошибка! Перемещение не удалось!"; exit 1; }
openvpn --genkey secret ta.key 									|| { echo "Ошибка! Генерация ключа не удалась!"; exit 1; } # генерируем публичный ключ тлс шифрования между сервером и клиентом
mv ta.key /etc/openvpn/server/ 									|| { echo "Ошибка! Перемещение не удалось!"; exit 1; } # переносим его в папку впн сервера
scp -i /home/$vpnUser/.ssh/id_rsa $caUser@$caIp:~/easy-rsa/pki/private/server.key /home/$vpnUser/|| { echo "Что-то пошло не так! Копирование не удалось!"; exit 1; } # копируем с уд.центра секретный ключ
mv /home/$vpnUser/server.key /etc/openvpn/server/  						|| { echo "Ошибка! Перемещение не удалось!"; exit 1; } # переносим секретный ключ в директорию сервера впн
dpkg -i /home/$vpnUser/artefacts/openvpn-server-config.deb 					|| { echo "Установка пакета не удалась. Проверьте логи."; exit 1; }
systemctl enable openvpn 									|| { echo "Сервис не запустился. Проверьте лог."; exit 1; }
systemctl -f enable openvpn-server@server.service 						|| { echo "Сервис не запустился. Проверьте лог." ; exit 1; }
systemctl start openvpn-server@server.service
chown $vpnUser:$vpnUser /etc/openvpn/server/ta.key
echo -e "\n ************* ВЫПОЛНЕННО ************* \n"

## Backup ##
echo -e "\n ************* НАСТРОЙКА BACKUP ************* \n"
# Активируем демон сервера rsync
cat <<EOF>> /etc/default/rsync
RSYNC_ENABLE=true
EOF
# создадим дирикторию для файлов rsync
if [ ! -d /etc/rsync/ ]; then
  mkdir  /etc/rsync/;
fi

cd /etc/rsync/								
echo "user:" > rsyncd.scrt
chmod 0600 /etc/rsync/rsyncd.scrt

# создадим файл конфигурации rsync-сервера
cat <<EOF> /etc/rsyncd.conf

pid file = /var/run/rsyncd.pid
lock file = /var/run/rsync.lock
log file = /var/log/rsync.log
[openvpn]
path = /etc/openvpn/
hosts allow = localhost 10.128.0.13 10.128.0.14
hosts deny = *
list = true
uid = user
gid = user
read only = yes
comment = openvpn folder
EOF

systemctl restart rsync.service   								# перезапуск службы rsync-сервера
echo -e "\n ************* ВЫПОЛНЕННО ************* \n"

echo -e "\n ************* НАСТРОЙКА И ЗАПУСК ЭКСПОРТЕРОВ ДЛЯ МОНИТОРИНГА ************* \n"
### openvpn-exporter ###
# Установка экспортера для openvpn
dpkg -i /home/$vpnUser/artefacts/openvpn-exporter_0.1-1.deb 					|| { echo "Установка пакета не удалась. Проверьте логи."; exit 1; }

### node exporter ###
read -p "Введите DNS-адрес машины VPN: " vpnAddr
if [ ! -d /opt/node_exporter ]; then
  mkdir  /opt/node_exporter;
fi

scp -i /home/$vpnUser/.ssh/id_rsa $caUser@$caIp:~/easy-rsa/pki/issued/$vpnAddr.crt /opt/node_exporter/ || { echo "Что-то пошло не так! Копирование не удалось!"; exit 1; } # перенос сертификата для сервера node_exporter на vpn-машине
scp -i /home/$vpnUser/.ssh/id_rsa $caUser@$caIp:~/easy-rsa/pki/private/$vpnAddr.key /opt/node_exporter/ || { echo "Что-то пошло не так! Копирование не удалось!" ; exit 1; } # перенос ключа для сервера node_exporter на vpn-машине
scp -i /home/$vpnUser/.ssh/id_rsa $caUser@$caIp:~/easy-rsa/pki/ca.crt /opt/node_exporter/ 		|| { echo "Что-то пошло не так! Копирование не удалось!"; exit 1; }  # перенос сертификата для нод экспортера

chmod 640 /opt/node_exporter/*.key
chmod 640 /opt/node_exporter/*.crt
chown prometheus:prometheus /opt/node_exporter/*
#chown  prometheus:prometheus /usr/bin/prometheus-node-exporter
chown  prometheus:prometheus /usr/bin/openvpn_exporter

# запросим данные для авторизации и запишем их в конфигурационный файл
    read -p "Node Exporter username: " username
    read -p "Node Exporter password: " -s password
    echo -e "tls_server_config:\n  cert_file: $vpnAddr.crt \n  key_file: $vpnAddr.key \n  client_auth_type: "RequireAndVerifyClientCert" \n  client_ca_file: ca.crt \n\nbasic_auth_users:\n  $username: '$(htpasswd -nbB -C 10 admin "$password" | grep -o "\$.*")'" >/opt/node_exporter/web.yml


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

cat <<EOF> /etc/systemd/system/openvpn_exporter.service
[Unit]
Description=Prometheus OpenVPN Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/bin/openvpn_exporter

[Install]
WantedBy=multi-user.target
EOF

# перезагрузим сервисы prometheus 
systemctl daemon-reload
systemctl restart prometheus-node-exporter.service
systemctl restart openvpn_exporter.service
echo -e "\n ************* ВЫПОЛНЕННО *************\n"
