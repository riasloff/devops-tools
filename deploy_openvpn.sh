#!/bin/bash

#1.Подготовка сервера

#1.1 Перед установкой ПО на OpenVPN сервере обновляем пакеты:
sudo apt-get update
sudo apt-get upgrade

#1.2 Устанавливаем минимальные настройки безопасности
sudo ufw allow OpenSSH
sudo ufw allow 1194/udp     # Для будущего тоннеля
sudo ufw enable
sudo ufw status

#1.3 Ставим пакеты необходимые для сервера (Лучше ставить с офф сайта последнюю доступную версию https://community.openvpn.net/openvpn/wiki/OpenvpnSoftwareRepos?_ga=2.18517361.957116946.1636379427-676591383.1634218888&__cf_chl_jschl_tk__=Ei4nCASUzbIcDAyheSPug9cZMsHzkouoGNERWulHzs8-1636533814-0-gaNycGzNCBE)
sudo apt install openvpn easy-rsa

#1.4 Так как у сертификатов есть период действия, во избежании ошибок при их генерации нужно чтоб на всех хостах было настроенно время и его автообновление. В противном случае может выдать ошибку о недействительном сертификате.
sudo apt-get install ntpdate
sudo  apt-get install -y ntp
sudo /etc/init.d/ntp stop
sudo ntpdate pool.ntp.org
sudo /etc/init.d/ntp start
#2. Настройка easy-rsa и генерация сертификатов

#2.1 Для правильного создания структуры PKI создаем катологи.
sudo mkdir /etc/srv-pki

#2.2 Создаем контейнер
sudo dd if=/dev/zero of=/etc/srv-pki/pki-openvpn.img bs=1 count=0 seek=1G status=progress

#2.3 Шифруем его и открываем
sudo cryptsetup luksFormat /etc/srv-pki/pki-openvpn.img         # Указываем пароль для контейнера.
sudo cryptsetup luksOpen /etc/srv-pki/pki-openvpn.img pki-openvpn

#2.4 Форматируем и создаем файловую систему
sudo mkfs.ext4 /dev/mapper/pki-openvpn

#2.5 Монтируем контейнер в ранее созданную папку
sudo mount /dev/mapper/pki-openvpn /etc/srv-pki/

#2.6 Создаем папку easy-rsa
sudo mkdir /etc/srv-pki/easy-rsa

#2.7 Создаем линку и удаляем ненужное
sudo ln -s /usr/share/easy-rsa/* /etc/srv-pki/easy-rsa
sudo rmdir /etc/srv-pki/lost+found

#2.8 Переходим в каталог и инициализируем его как PKI
cd /etc/srv-pki/easy-rsa/

sudo ./easyrsa init-pki

# Можно указать параметро nopass для создания сертификата без пароля, это не безопастно, но иначе придется его вводить каждый раз при требовании.
sudo ./easyrsa build-ca

#Таблица назначения ключей
#dh.pem Файл Диффи-Хелмана для защиты трафика от расшифровки
#ca.crt Cертификат удостоверяющего центра CA
#server.crt Сертификат сервера OpenVPN
#server.key Приватный ключ сервера OpenVPN, секретный
#crl.pem Список отзыва сертификатов CRL
#ta.key Ключ HMAC для дополнительной защиты от DoS-атак и флуда

#2.9 Копируем файл, открываем его и редактируем нужные строчки.
sudo cp /usr/share/easy-rsa/vars.example /etc/srv-pki/easy-rsa/vars
sudo nano /etc/srv-pki/easy-rsa/vars

# Находим и приводим к данному ввиду строчки
#set_var EASYRSA_REQ_COUNTRY    "US"
#set_var EASYRSA_REQ_PROVINCE   "NewYork"
#set_var EASYRSA_REQ_CITY       "New York City"
#set_var EASYRSA_REQ_ORG        "CA"
#set_var EASYRSA_REQ_EMAIL      "admin@example.com"
#set_var EASYRSA_REQ_OU         "Community"
#set_var EASYRSA_CERT_EXPIRE    "3650"
#set_var EASYRSA_ALGO           "ec"
#set_var EASYRSA_DIGEST         "sha512"

#2.10 После подготовки структуры PKI, создадим первую пару ключей для сервера, в нашем случае OpenVPN сервер.
# Создаем запрос
sudo ./easyrsa gen-req OpenVPN nopass

# Далее подписываем запрос
sudo ./easyrsa sign-req server OpenVPN
# Здесь "server" значение из пула client/server
 
# Если запрос на сертификат был создан на другом хосте (gen-req) то прежде чем подписать его необходимо импортировать, например:
# ./easyrsa import-req /tmp/client1.req client1

#2.11 Генерим список отзыва сертификатов и файл Диффи-Хелмана
sudo ./easyrsa gen-crl
sudo ./easyrsa gen-dh

# 2.12 Даём права группе и пользователям
# sudo chown -R root:toweradmins /etc/srv-pki/
# sudo chmod -R 070 /etc/srv-pki
#3. Настройка OpenVPN сервера

#3.1 Копируем конфиг файл
sudo cp /etc/srv-pki/easy-rsa/openssl-easyrsa.cnf /etc/openvpn/server/openssl.conf

#3.2.1 Открываем его и меняем следующие строки :
sudo nano /etc/openvpn/server/openssl.conf
dir             = /etc/openvpn/server
private_key     = $dir/private/OpenVPN.key
unique_subject  = yes

#3.2.2 Создаем каталог для приватного ключа в директории /etc/openvpn/server/
sudo mkdir /etc/openvpn/server/private

# Client config dir
sudo mkdir /etc/openvpn/ccd

#3.3 Создаем файл конфига сервера, и редактируем его.
sudo nano /etc/openvpn/server.conf

server.conf :
port 1194
proto udp
dev tun
 
# Certs
ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/OpenVPN.crt
key /etc/openvpn/server/private/OpenVPN.key
crl-verify /etc/openvpn/server/crl.pem
dh /etc/openvpn/server/dh.pem

# Network
server 10.10.10.0 255.255.255.0
topology subnet
push "route 10.10.10.0 255.255.255.0"
keepalive 10 120
reneg-sec 21600

# tls
tls-crypt /etc/openvpn/server/ta.key 0
tls-server
remote-cert-tls client
tls-version-min 1.3

# plugin to work with 2FA
# plugin /usr/lib/x86_64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so openvpn

cipher AES-256-GCM
auth SHA256

user nobody
group nogroup

persist-key
persist-tun

# logs
ifconfig-pool-persist /var/log/openvpn/ipp.txt
status /var/log/openvpn/openvpn-status.log
log         /var/log/openvpn/openvpn.log
log-append  /var/log/openvpn/openvpn.log
verb 3
explicit-exit-notify 1

#3.4 Копируем сертификаты
sudo cp /etc/srv-pki/easy-rsa/pki/ca.crt /etc/openvpn/server/
sudo cp /etc/srv-pki/easy-rsa/pki/issued/OpenVPN.crt /etc/openvpn/server/
sudo cp /etc/srv-pki/easy-rsa/pki/private/OpenVPN.key /etc/openvpn/server/private/
sudo cp /etc/srv-pki/easy-rsa/pki/crl.pem /etc/openvpn/server/
sudo cp /etc/srv-pki/easy-rsa/pki/dh.pem /etc/openvpn/server/

#3.5 Генерим ta.key, назначение см. таб. пункт 2.8
sudo openvpn --genkey secret /etc/openvpn/server/ta.key

#3.6 Добавляем системного пользователя для корректной работы сервиса OpenVPN
sudo useradd openvpn -r
sudo chown openvpn -R /etc/openvpn

#3.6 Запуск сервера
sudo systemctl enable openvpn@server.service
sudo systemctl start openvpn@server.service
sudo systemctl status openvpn@server.service
#4. Настройка Google-2FA и выпуск сертификата для пользователя

#4.1 Ставим необходимый пакет
sudo apt-get install libpam-google-authenticator

#4.2 Создаем файл openvpn и добавляем
sudo nano /etc/pam.d/openvpn

#4.3 Надо выполнить эту команду чтоб всё работало
echo ‘auth required /lib/x86_64-linux-gnu/security/pam_google_authenticator.so secret=/etc/openvpn/google-authenticator/${USER} user=gauth forward_pass debug’ | sudo tee /etc/pam.d/openvpn

#4.4 Создаем каталог для google-authenticator
sudo mkdir /etc/openvpn/google-authenticator

#4.5 Добавляем пользователя и даём права
sudo useradd gauth -r
sudo chown gauth:gauth -R /etc/openvpn/google-authenticator
sudo chmod 0700 -R /etc/openvpn/google-authenticator

#4.6 Создаем пользователя 2FA
sudo -H -u gauth google-authenticator -t -w3 -e10 -d -r3 -R30 -f -l “client1 -s /etc/openvpn/google-authenticator/client1
#5. Настройка клиентов OpenVPN сервера

#5.1 Установка пакета openvpn
sudo apt-get install openvpn
#5.2 См. пункт 1.3 и настраиваем время, это важный пункт !

#5.3 Переходим в каталог Easy-rsa на сервере OpenVPN и создаем сертификат для клиента.
./easyrsa gen-req client1 nopass
./easy-rsa sign-req client client1 # Then write "yes"

#Полученные файлы можно передать хосту любым безопасным способом, либо поместить в один конфиг файл. Мы воспользуемся вторым способом, помещением всех ключей и сертификатов в один файл.

#5.4 Создаем файл конфиг клиента
sudo nano /etc/openvpn/client.conf

#5.5 И Настраиваем его таким же образом как в нашем примере
client
dev tun
proto udp
remote your_srv_addr 1194
resolv-retry infinite
nobind
user nobody
group nogroup
persist-key
persist-tun
key-direction 1
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
verb 3
reneg-sec 0

# Should on, if you use 2FA
# auth-user-pass
# auth-nocache
<ca>

</ca>

<cert>

</cert>

<key>

</key>

<tls-crypt>

</tls-crypt>

#5.7 Повторяем пункт 3.6
sudo useradd openvpn -r
sudo chown openvpn -R /etc/openvpn

#5.8 Запускам службу
sudo systemctl enable openvpn@client.service
sudo systemctl start openvpn@client.service
sudo systemctl status openvpn@client.service

#Для проверки вводим ip a и проверяем поднялся ли тоннель
#Следом после любых изменений с пользователями (добавление и отзыв сертификатов) обязательно генерить новый CRL файл см. пункт 2.12 и поместить его в каталог openVPN или например nginx. После этого рекомендуется рестартануть сервис, чтоб подцепились изменения.
#6. Полезное

#Для блокировки пользователя и отзыва сертификата можно воспользоваться следующей командой, после этого не забываем про crl.pem
sudo ./easyrsa revoke example

#Скрипт для автоматизации помещения ключей и сертификатов в конфиг клиента
#!/bin/bash

# First argument: Client identifier

KEY_DIR=/etc/openvpn/client/keys
OUTPUT_DIR=/etc/openvpn/client/files
BASE_CONFIG=/etc/openvpn/client/client.conf

cat ${BASE_CONFIG} \
<(echo -e '<ca>') \
${KEY_DIR}/ca.crt \
<(echo -e '</ca>\n<cert>') \
${KEY_DIR}/${1}.crt \
<(echo -e '</cert>\n<key>') \
${KEY_DIR}/${1}.key \
<(echo -e '</key>\n<tls-crypt>') \
${KEY_DIR}/ta.key \
<(echo -e '</tls-crypt>') \
> ${OUTPUT_DIR}/${1}.ovpn
