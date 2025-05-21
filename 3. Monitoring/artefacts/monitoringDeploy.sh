#! /bin/bash
set -e
# Outputs an error (in STDERR) and terminates the script
# if the script is run without superuser rights
(( EUID != 0 )) && { echo 'The script needs superuser rights.' >&2; exit 1; }

echo -e "\n ************* НАСТРОЙКА И СИНХРОНИЗАЦИЯ ВРЕМЕНИ *************\n"
# синхронизация времени по определенному часовому поясу всех машин
timedatectl set-timezone Europe/Moscow
systemctl restart systemd-timesyncd.service

echo -e "\n ************* НАСТРОЙКА SSH *************\n"
# настройка ssh
sed -i 's/#\?\(PermitRootLogin\s*\).*$/\1 no/' /etc/ssh/sshd_config
sed -i 's/#\?\(PubkeyAuthentication\s*\).*$/\1 yes/' /etc/ssh/sshd_config
sed -i 's/#\?\(PermitEmptyPasswords\s*\).*$/\1 no/' /etc/ssh/sshd_config
sed -i 's/#\?\(PasswordAuthentication\s*\).*$/\1 no/' /etc/ssh/sshd_config

cat <<EOF>> /etc/ssh/ssh_config
StrictHostKeyChecking accept-new
EOF
echo -e "\n ************* ВЫПОЛНЕННО *************\n"

caIp=10.128.0.10  # адрес машины удостоверяющего центра в сети

read -p "Введите имя пользователя сервера мониторинга: " monUser
read -p "Введите имя пользователя удостоверяющего центра: " caUser

echo -e "\n ************* УСТАНОВКА НЕОБХОДИМЫХ ПАКЕТОВ *************\n"
# установка необходимых пакетов
apt-get update && apt-get install -y iptables prometheus prometheus-alertmanager prometheus-node-exporter apache2-utils	|| { echo "Установка пакетов не удалась!"; exit 1; }
echo-e "\n  ************* ВЫПОЛНЕННО *************\n"

echo -e "\n ************* УСТАНОВКА ПРАВИЛ IPtables *************\n"
cd /home/$monUser/artefacts && bash monIPtablesRules.sh								|| { echo "Что-то пошло не так! Настройка фаервола не удалась!"; exit 1; }
echo -e "\n ************* ВЫПОЛНЕННО *************\n"

echo -e "\n ************* УСТАНОВКА ПРАВИЛ ALERTMANAGER *************\n"
cd /home/$monUser/artefacts && dpkg --install alertmanager-rules_0.1-1.deb					|| { echo "Что-то пошло не так! Распаковка правил не удалась!" ; exit 1; }
echo -e "\n ************* ВЫПОЛНЕННО *************\n"

echo-e "\n  ************* НАСТРОЙКА ФАЙЛА КОНФИГУРАЦИИ PROMETHEUS *************\n"
# внесем необходимые настройки в файл конфигурации prometheus.yml
cat <<EOF> /etc/prometheus/prometheus.yml
global:
  scrape_interval:     15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.

  external_labels:
      monitor: 'example'

alerting:
  alertmanagers:
  - static_configs:
    - targets: ['localhost:9093']

rule_files:
   - "./alertmanager-data/ca-rules.yml"
   - "./alertmanager-data/backup-rules#1.yml"
   - "./alertmanager-data/backup-rules#2.yml"
   - "./alertmanager-data/vpn-rules.yml"
   - "./alertmanager-data/monitoring-rules.yml"

scrape_configs:
  - job_name: prometheus
    scheme: https
    basic_auth:
      username: admin
      password: paswd
    tls_config:
      ca_file: ca.crt
      cert_file: 'monitoring.ru-central1.internal.crt'
      key_file: 'monitoring.ru-central1.internal.key'
    scrape_interval: 5s
    scrape_timeout: 5s
    static_configs:
      - targets: ['localhost:9090']

  - job_name: node-monitoring
    scheme: https
    basic_auth:
      username: admin
      password: paswd
    tls_config:
      ca_file: ca.crt
      cert_file: 'monitoring.ru-central1.internal.crt'
      key_file: 'monitoring.ru-central1.internal.key'
    scrape_interval: 5s
    scrape_timeout: 5s
    static_configs:
      - targets: ['localhost:9100']

  - job_name: node-CA
    scheme: https
    basic_auth:
      username: admin
      password: paswd
    tls_config:
      ca_file: ca.crt
      cert_file: 'monitoring.ru-central1.internal.crt'
      key_file: 'monitoring.ru-central1.internal.key'
    scrape_interval: 5s
    scrape_timeout: 5s
    static_configs:
      - targets: ['ca.ru-central1.internal:9100']

  - job_name: node-VPN
    scheme: https
    basic_auth:
      username: admin
      password: paswd
    tls_config:
      ca_file: ca.crt
      cert_file: 'monitoring.ru-central1.internal.crt'
      key_file: 'monitoring.ru-central1.internal.key'
    scrape_interval: 5s
    scrape_timeout: 5s
    static_configs:
      - targets: ['vpn.ru-central1.internal:9100']


  - job_name: node-backup#1
    scheme: https
    basic_auth:
      username: admin
      password: paswd
    tls_config:
      ca_file: ca.crt
      cert_file: 'monitoring.ru-central1.internal.crt'
      key_file: 'monitoring.ru-central1.internal.key'
    scrape_interval: 5s
    scrape_timeout: 5s
    static_configs:
      - targets: ['bkp1.ru-central1.internal:9100']


  - job_name: node-backup#2
    scheme: https
    basic_auth:
      username: admin
      password: paswd
    tls_config:
      ca_file: ca.crt
      cert_file: 'monitoring.ru-central1.internal.crt'
      key_file: 'monitoring.ru-central1.internal.key'
    scrape_interval: 5s
    scrape_timeout: 5s
    static_configs:
      - targets: ['bkp2.ru-central1.internal:9100']


  - job_name: openVPN
    scheme: http
#    basic_auth:
#      username: admin
#      password: paswd
#    tls_config:
#      ca_file: ca.crt
#      cert_file: 'monitoring.ru-central1.internal.crt'
#      key_file: 'monitoring.ru-central1.internal.key'
    scrape_interval: 5s
    scrape_timeout: 5s
    static_configs:
      - targets: ['vpn.ru-central1.internal:9176']

EOF
echo -e "\n ************* ВЫПОЛНЕННО *************\n"

echo -e "\n ************* НАСТРОЙКА ФАЙЛА КОНФИГУРАЦИИ ALERTMANAGER *************\n"
# внесем необходимые настройки в файл конфигурации alertmanager.yml
cat <<EOF> /etc/prometheus/alertmanager.yml   
global:
  # The smarthost and SMTP sender used for mail notifications.
  smtp_smarthost: 'localhost:25'
  smtp_from: 'alertmanager@example.org'
  smtp_auth_username: 'alertmanager'
  smtp_auth_password: 'password'

templates: 
- '/etc/prometheus/alertmanager_templates/*.tmpl'
route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 3h 

  # A default receiver
  receiver: mailNotify
  routes:
  - match_re:
      service: ^(foo1|foo2|baz)$
    receiver: #team-X-mails
    routes:
    - match:
        severity: critical
      receiver: mailNotify
  - match:
      service: files
    receiver: team-Y-mails

    routes:
    - match:
        severity: critical
      receiver: mailNotify
  - match:
      service: database
    receiver: team-DB-pager
    # Also group alerts by affected database.
    group_by: [alertname, cluster, database]
    routes:
    - match:
        owner: team-X
      receiver: team-X-pager
    - match:
        owner: team-Y
      receiver: team-Y-pager
inhibit_rules:
- source_match:
    severity: 'critical'
  target_match:
    severity: 'warning'
  # Apply inhibition if the alertname is the same.
  equal: ['alertname', 'cluster', 'service']

receivers:
- name: mailNotify
  email_configs:
  - to: 'aslikeme@mail.ru'
    from: 'cl4ssique@yandex.ru'
    smarthost: 'smtp.yandex.ru:465'
    auth_username: 'cl4ssique@yandex.ru'
    auth_identity: 'cl4ssique@yandex.ru'
    auth_password: 'fffebaanztlxecyz'
    send_resolved: true
    require_tls: false

- name: 'team-X-pager'
  email_configs: 
  - to: 'team-X+alerts-critical@example.org'
  pagerduty_configs:
  - service_key: <team-X-key>

- name: 'team-Y-mails'
  email_configs:
  - to: 'team-Y+alerts@example.org'

- name: 'team-Y-pager'
  pagerduty_configs:
  - service_key: <team-Y-key>

- name: 'team-DB-pager'
  pagerduty_configs:
  - service_key: <team-DB-key>

EOF

systemctl restart prometheus.service
systemctl restart prometheus-alertmanager.service
echo -e "\n ************* ВЫПОЛНЕННО *************\n"

## Backup ##
echo -e "\n ************* НАСТРОЙКА BACKUP *************\n"
# активируем демон rsync
cat <<EOF>> /etc/default/rsync
RSYNC_ENABLE=true
EOF
# создадим дирикторию для файлов rsync
if [ ! -d /etc/rsync/ ]; then
  mkdir  /etc/rsync/;
fi

cd /etc/rsync/	&& echo "$monUser:" > rsyncd.scrt
chmod 0600 /etc/rsync/rsyncd.scrt

# создадим файл конфигурации rsync-сервера
cat <<EOF> /etc/rsyncd.conf

pid file = /var/run/rsyncd.pid
lock file = /var/run/rsync.lock
log file = /var/log/rsync.log
[prometheus]
path = /etc/prometheus
hosts allow = localhost 10.128.0.13 10.128.0.14
hosts deny = *
list = true
uid = user
gid = user
read only = yes
comment = prometheus folder
EOF

systemctl restart rsync.service    						# перезапуск службы rsync-сервера
echo -e "\n ************* ВЫПОЛНЕННО *************\n"

##### Prometheus ######
echo -e "\n ************* РАЗВЕРТЫВАНИЕ СИСТЕМЫ ЛОКАЛЬНОГО МОНИТОРИНГА *************\n"
#создадим рабочий каталог для node_exporter
if [ ! -d /opt/node_exporter ]; then
  mkdir  /opt/node_exporter;
fi

read -p "Введите DNS-адрес машины мониторинга: " monitoringAddr

scp -i /home/$monUser/.ssh/id_rsa $caUser@$caIp:~/easy-rsa/pki/issued/localhost.crt /home/$monUser/	|| { echo "Что-то пошло не так! Копирование не удалось!"; exit 1; } # перенос сертификата node_exporter на сервер мониторинга
scp -i /home/$monUser/.ssh/id_rsa $caUser@$caIp:~/easy-rsa/pki/private/localhost.key /home/$monUser/	|| { echo "Что-то пошло не так! Копирование не удалось!"; exit 1; } # перенос ключа node_exporter на сервер мониторинга
scp -i /home/$monUser/.ssh/id_rsa $caUser@$caIp:~/easy-rsa/pki/issued/$monitoringAddr.crt /home/$monUser/|| { echo "Что-то пошло не так! Копирование не удалось!"; exit 1; } # перенос сертификата клиента экспортера на сервер мониторинга
scp -i /home/$monUser/.ssh/id_rsa $caUser@$caIp:~/easy-rsa/pki/private/$monitoringAddr.key /home/$monUser/|| { echo "Что-то пошло не так! Копирование не удалось!"; exit 1; } # перенос ключа клиента экспортера на сервер мониторинга
scp -i /home/$monUser/.ssh/id_rsa $caUser@$caIp:~/easy-rsa/pki/ca.crt /home/$monUser/			|| { echo "Что-то пошло не так! Копирование не удалось!"; exit 1; } # перенос корневого сертификата на сервер мониторинга

mv /home/$monUser/$monitoringAddr.crt /etc/prometheus/
mv /home/$monUser/$monitoringAddr.key /etc/prometheus/
cp /home/$monUser/ca.crt /etc/prometheus/
cp /home/$monUser/ca.crt /opt/node_exporter/
cp /home/$monUser/localhost.crt /opt/node_exporter/ && cp /home/$monUser/localhost.crt /etc/prometheus/
cp /home/$monUser/localhost.key /opt/node_exporter/ && cp /home/$monUser/localhost.key /etc/prometheus/

chmod 640 /etc/prometheus/*.crt
chmod 640 /etc/prometheus/*.key
chown prometheus:prometheus /etc/prometheus/*

# запросим username и password для авторизации в программе
read -p "Prometheus username: " username
read -p "Prometheus password: " -s password

# запишем настройки в конфигурационный файл /etc/prometheus/web.yml
echo -e "tls_server_config:\n  cert_file: $monitoringAddr.crt \n  key_file: $monitoringAddr.key \n\nbasic_auth_users:\n  $username: '$(htpasswd -nbB -C 10 admin "$password" | grep -o "\$.*")'" >/etc/prometheus/web.yml

# внесем изменения в конфигурационный файл /etc/prometheus/prometheus.yml в блок alerting
sed -r -i '0,/(^.*\susername:\s).*$/s//\1'"$username"'/' /etc/prometheus/prometheus.yml
sed -r -i '0,/(^.*\spassword:\s).*$/s//\1'"$password"'/' /etc/prometheus/prometheus.yml
chown prometheus:prometheus /etc/prometheus/*

cat <<EOF> /etc/systemd/system/multi-user.target.wants/prometheus.service

[Unit]
Description=Monitoring system and time series database
Documentation=https://prometheus.io/docs/introduction/overview/ man:prometheus(1)
After=time-sync.target

[Service]
Restart=on-failure
User=prometheus
EnvironmentFile=/etc/default/prometheus
ExecStart=/usr/bin/prometheus $ARGS --web.config.file=/etc/prometheus/web.yml
ExecReload=/bin/kill -HUP $MAINPID
TimeoutStopSec=20s
SendSIGKILL=no

# systemd hardening-options
AmbientCapabilities=
CapabilityBoundingSet=
DeviceAllow=/dev/null rw
DevicePolicy=strict
LimitMEMLOCK=0
LimitNOFILE=8192
LockPersonality=true
MemoryDenyWriteExecute=true
NoNewPrivileges=true
PrivateDevices=true
PrivateTmp=true
PrivateUsers=true
ProtectControlGroups=true
ProtectHome=true
ProtectKernelModules=true
ProtectKernelTunables=true
ProtectSystem=full
RemoveIPC=true
RestrictNamespaces=true
RestrictRealtime=true
SystemCallArchitectures=native

[Install]
WantedBy=multi-user.target

EOF

### node exporter ###
chmod 640 /opt/node_exporter/*.key
chmod 640 /opt/node_exporter/*.crt
chown -R prometheus:prometheus /opt/node_exporter/

# запросим данные для авторизации и запишем их в конфигурационный файл
    read -p "Node Exporter username: " nodeUsername
    read -p "Node Exporter password: " -s nodePassword
    echo -e "tls_server_config:\n  cert_file: localhost.crt \n  key_file: localhost.key \n  client_auth_type: "RequireAndVerifyClientCert" \n  client_ca_file: ca.crt \n\nbasic_auth_users:\n  $nodeUsername: '$(htpasswd -nbB -C 10 admin "$nodePassword" | grep -o "\$.*")'" >/opt/node_exporter/web.yml


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

# перезагрузим сервисы prometheus и alertmanager
systemctl daemon-reload
systemctl restart prometheus.service
systemctl restart prometheus-alertmanager.service
systemctl restart prometheus-node-exporter.service
echo -e "\n ************* ВЫПОЛНЕННО ************* \n"
