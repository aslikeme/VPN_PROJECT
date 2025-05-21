#! /bin/bash
set -e
# Outputs an error (in STDERR) and terminates the script
# if the script is run without superuser rights
(( EUID != 0 )) && { echo 'The script needs superuser rights.' >&2; exit 1; }

echo -e "\n ************* НАСТРОЙКА И СИНХРОНИЗАЦИЯ ВРЕМЕНИ ************* \n"
# синхронизация времени по определенному часовому поясу всех машин
timedatectl set-timezone Europe/Moscow
systemctl restart systemd-timesyncd.service

echo -e "\n ************* УСТАНОВКА НЕОБХОДИМЫХ ПАКЕТОВ ************* \n"
# установка необходимых пакетов
apt-get install -y iptables easy-rsa prometheus-node-exporter apache2-utils	|| { echo "Установка пакетов не удалась!" ; exit 1; }
echo -e "\n ************* ВЫПОЛНЕННО ************* \n"

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

echo -e " \n ************* УСТАНОВКА ПРАВИЛ IPtables ************* \n"
read -p "Введите имя пользователя удостоверяющего центра: " caUser 
bash /home/$caUser/artefacts/caIPtablesRules.sh                                 || { echo "Что-то пошло не так! Настройка фаервола не удалась!" ; exit 1; }
echo -e "\n ************* ВЫПОЛНЕННО ************* \n"

echo -e "\n ************* РАЗВЕРТЫВАНИЕ ИНФРАСТРУКТУРЫ  EASY-RSA ************* \n"
# Создаем папку где будут располагаться скрипты для работы с easy-rsa
if [ ! -d /home/$caUser/easy-rsa ]; then
  mkdir  /home/$caUser/easy-rsa;
fi

ln -s /usr/share/easy-rsa/*  /home/$caUser/easy-rsa/ 				# Создаем ссылку на нашу созданную папку, чтобы получить все необходимые файлы из шаблонов easy-rsa
chmod 700 /home/$caUser/easy-rsa/ 						# устанавливаем права на папку с ограничением для всех кроме владельца 
cd /home/$caUser/easy-rsa && ./easyrsa init-pki 				# создаем директорию для инфраструктуры публичных ключей
chown -R $caUser:$caUser /home/$caUser/easy-rsa/
dpkg -i /home/$caUser/artefacts/config-file-for-easyrsa.deb 			|| { echo "Установка пакета не удалась!" ; exit 1; }
cd /home/$caUser/easy-rsa && ./easyrsa build-ca 				|| { echo "Генерация открытого ключа не удалась!" ; exit 1; } # Генерируем ключи нашего уд. центра !!! запросит пас фразу !!!
cd /home/$caUser/easy-rsa && ./easyrsa gen-req server nopass 			|| { echo "Генерация файла запроса не удалась!" ; exit 1; } # Генерируем файл запроса сертификата и секретный ключ для vpn-сервера
cd /home/$caUser/easy-rsa && ./easyrsa sign-req server server 			|| { echo "Подписание запроса не удалось!" ; exit 1; } # Подписываем запрос на серверный сертификат для сервера “server” !!! запросит пас фразу !!!
chown -R $caUser:$caUser /home/$caUser/easy-rsa/*
echo -e " \n ************* ВЫПОЛНЕННО ************* \n"


## Backup ##
echo -e " \n ************* НАСТРОЙКА BACKUP ************* \n"
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
[easy-rsa]
path = /home/$caUser/easy-rsa
hosts allow = localhost 10.128.0.13 10.128.0.14
hosts deny = *
list = true
uid = $caUser
gid = $caUser
read only = yes
comment = EASY-RSA folder
EOF

systemctl restart rsync.service  						# перезапуск службы rsync-сервера
echo -e "\n ************* ВЫПОЛНЕННО ************* \n"


## monitoring ##
echo -e "\n ************* ГЕНЕРАЦИЯ КЛЮЧЕЙ И СЕРТИФИКАТОВ ДЛЯ ЭКСПОРТЕРОВ В ИНФРАСТРУКТУРЕ *************\n"
read -p "Введите DNS-адрес машины CA: " caAddr
read -p "Введите DNS-адрес машины мониторинга: " monitoringAddr
read -p "Введите DNS-адрес машины VPN: " vpnAddr
read -p "Введите DNS-адрес машины №1 резервного копирования: " bkp1Addr
read -p "Введите DNS-адрес машины №2 резервного копирования: " bkp2Addr

cd /home/$caUser/easy-rsa && ./easyrsa gen-req $caAddr nopass 			|| { echo "Генерация файла запроса не удалась!" ; exit 1; } # Генерируем файл запроса сертификата для сервера node_exporter на ca-машине
cd /home/$caUser/easy-rsa && ./easyrsa sign-req server $caAddr 			|| { echo "Подписание запроса не удалось!" ; exit 1; } # Подписываем запрос на серверный сертификат для сервера node_exporter на ca-машине
cd /home/$caUser/easy-rsa && ./easyrsa gen-req $monitoringAddr nopass 		|| { echo "Генерация файла запроса не удалась!" ; exit 1; } # Генерируем файл запроса сертификата для сервера node_exporter на monitoring-машине
cd /home/$caUser/easy-rsa && ./easyrsa sign-req client $monitoringAddr 		|| { echo "Подписание запроса не удалось!" ; exit 1; } # Подписываем запрос на серверный сертификат для клиента node_exporter на monitoring-машине
cd /home/$caUser/easy-rsa && ./easyrsa gen-req localhost nopass 					|| { echo "Генерация файла запроса не удалась!" ; exit 1; } # Генерируем файл запроса сертификата для сервера node_exporter на monitoring-машине
cd /home/$caUser/easy-rsa && ./easyrsa sign-req server localhost 					|| { echo "Подписание запроса не удалось!" ; exit 1; } # Подписываем запрос на серверный сертификат для сервера node_exporter на monitoring-машине
cd /home/$caUser/easy-rsa && ./easyrsa gen-req $vpnAddr nopass 			|| { echo "Генерация файла запроса не удалась!" ; exit 1; } # Генерируем файл запроса сертификата для сервера node_exporter на vpn-машине
cd /home/$caUser/easy-rsa && ./easyrsa sign-req server $vpnAddr 			|| { echo "Подписание запроса не удалось!" ; exit 1; } # Подписываем запрос на серверный сертификат для сервера node_exporter на vpn-машине
cd /home/$caUser/easy-rsa && ./easyrsa gen-req $bkp1Addr nopass 			|| { echo "Генерация файла запроса не удалась!" ; exit 1; } # Генерируем файл запроса сертификата для сервера node_exporter на bkp1-машине
cd /home/$caUser/easy-rsa && ./easyrsa sign-req server $bkp1Addr 			|| { echo "Подписание запроса не удалось!" ; exit 1; } # Подписываем запрос на серверный сертификат для сервера node_exporter на bkp1-машине
cd /home/$caUser/easy-rsa && ./easyrsa gen-req $bkp2Addr nopass 			|| { echo "Генерация файла запроса не удалась!" ; exit 1; } # Генерируем файл запроса сертификата для сервера node_exporter на bkp2-машине
cd /home/$caUser/easy-rsa && ./easyrsa sign-req server $bkp2Addr 			|| { echo "Подписание запроса не удалось!" ; exit 1; } # Подписываем запрос на серверный сертификат для сервера node_exporter на bkp2-машине
chown -R $caUser:$caUser /home/$caUser/easy-rsa/*
echo -e "\n ************* ВЫПОЛНЕННО ************* \n"


### node exporter ###
echo -e "\n ************* НАСТРОЙКА И ЗАПУСК ЭКСПОРТЕРОВ ДЛЯ МОНИТОРИНГА ************* \n"

if [ ! -d /opt/node_exporter ]; then
  mkdir  /opt/node_exporter;
fi

cp /home/$caUser/easy-rsa/pki/issued/$caAddr.crt /opt/node_exporter/ || { echo "Что-то пошло не так! Копирование не удалось!" ; exit 1; } # перенос сертификата сервера в папку экспортера
cp /home/$caUser/easy-rsa/pki/private/$caAddr.key /opt/node_exporter/ || { echo "Что-то пошло не так! Копирование не удалось!" ; exit 1; } # перенос ключа сервера в папку экспортера
cp /home/$caUser/easy-rsa/pki/ca.crt /opt/node_exporter/ || { echo "Что-то пошло не так! Копирование не удалось!" ; exit 1; } # перенос корневого сертификата в папку экспортера
chmod 640 /opt/node_exporter/*.key
chmod 640 /opt/node_exporter/*.crt

# запросим данные для авторизации и запишем их в конфигурационный файл
    read -p "Node Exporter username: " username
    read -p "Node Exporter password: " -s password
    echo -e "tls_server_config:\n  cert_file: $caAddr.crt \n  key_file: $caAddr.key \n  client_auth_type: "RequireAndVerifyClientCert" \n  client_ca_file: ca.crt \n\nbasic_auth_users:\n  $username: '$(htpasswd -nbB -C 10 admin "$password" | grep -o "\$.*")'" >/opt/node_exporter/web.yml
chown prometheus:prometheus /opt/node_exporter/*

cat <<EOF> /etc/systemd/system/multi-user.target.wants/prometheus-node-exporter.service
[Unit]
Description=Prometheus exporter for machine metrics
Documentation=https://github.com/prometheus/node_exporter

[Service]
Restart=on-failure
User=prometheus
EnvironmentFile=/etc/default/prometheus-node-exporter
ExecStart=/usr/bin/prometheus-node-exporter --web.config=/opt/node_exporter/web.yml  $ARGS
ExecReload=/bin/kill -HUP $MAINPID
TimeoutStopSec=20s
SendSIGKILL=no

[Install]
WantedBy=multi-user.target

EOF

# перезагрузим сервисы prometheus
systemctl daemon-reload
systemctl restart prometheus-node-exporter.service
echo -e "\n ************* ВЫПОЛНЕННО ************* \n"
