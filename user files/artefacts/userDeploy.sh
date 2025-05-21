#! /bin/bash
set -e
# Outputs an error (in STDERR) and terminates the script
# if the script is run without superuser rights
(( EUID != 0 )) && { echo 'The script needs superuser rights.' >&2; exit 1; }

read -p "Введите имя пользователя: " userName

echo -e "\n ************* УСТАНОВКА НЕОБХОДИМЫХ ПАКЕТОВ ************* \n"
apt update &&  apt install easy-rsa -y

echo -e "\n ************* РАЗВЕРТЫВАНИЕ ИНФРАСТРУКТУРЫ  EASY-RSA ************* \n"
mkdir -p /home/$userName/keys # Для удобства создадим директорию clients для сертификатов клиентов
mkdir -p /home/$userName/easy-rsa  # Создаем папку где будут располагаться скрипты для работы с easy-rsa
ln -s /usr/share/easy-rsa/*  /home/$userName/easy-rsa/ # Создаем ссылку на нашу созданную папку, чтобы получить все необходимые файлы из шаблонов easy-rsa
chmod 700 /home/$userName/easy-rsa/ # устанавливаем права на папку с ограничением для всех кроме владельца 
chmod 700 /home/$userName/keys/
cd /home/$userName/easy-rsa && ./easyrsa init-pki # создаем директорию для инфраструктуры публичных ключей
chown -R $userName:$userName /home/$userName/easy-rsa/
dpkg -i /home/$userName/artefacts/config-file-for-easyrsa.deb 					|| { echo "Установка пакета не удалась!"; exit 1; }
dpkg -i /home/$userName/artefacts/openvpn-client-config.deb                                   || { echo "Установка пакета не удалась!"; exit 1; }
chown -R $userName:$userName /home/$userName/easy-rsa/
echo -e " \n ************* СОЗДАНИЕ КЛЮЧА И СЕРТИФИКАТА ПОЛЬЗОВАТЕЛЯ ************* \n"
cd /home/$userName/easy-rsa && ./easyrsa gen-req $userName# nopass
cp /home/$userName/easy-rsa/pki/private/$userName#.key /home/$userName/keys/  			|| { echo "Копирование файла не удалось!"; exit 1;} # копируем полученный ключ 
cp /home/$userName/easy-rsa/pki/reqs/$userName#.req /home/$userName/keys/  			|| { echo "Копирование файла не удалось!"; exit 1; } # копируем запрос 
chown -R $userName:$userName /home/$userName/easy-rsa/pki/reqs

