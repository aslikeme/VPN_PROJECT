#!/bin/bash

# Default Variable Declarations
read -p "Введите имя пользователя клиента: " user
DEFAULT="/home/$user/base.conf"
FILEEXT=".ovpn"
CRT=".crt"
KEY=".key"
CA="ca.crt"
TA="/home/$user/keys/ta.key"
kPath="/home/$user/keys/"
cPath="/home/$user/keys/"

#Ask for a Client name
echo "Please enter an existing Client Name:"
read NAME

echo "Please enter an Name for the output file"
read ovpnName

#1st Verify that client's Public Key Exists
if [ ! -f $kPath$NAME$CRT ]; then
   echo "[ERROR]: Client Public Key Certificate not found: $kPath$NAME$CRT"
   exit
fi
echo "Client's cert found: $kPath$NAME$CRT"

#Then, verify that there is a private key for that client
if [ ! -f $kPath$NAME$KEY ]; then
   echo "[ERROR]: Client 3des Private Key not found: $kPath$NAME$KEY"
   exit
fi
echo "Client's Private Key found: $kPath$NAME$KEY"

#Confirm the CA public key exists
if [ ! -f $cPath$CA ]; then
   echo "[ERROR]: CA Public Key not found: $cPath$CA"
   exit
fi
echo "CA public Key found: $cPath$CA"

#Confirm the tls-auth ta key file exists
if [ ! -f $TA ]; then
   echo "[ERROR]: tls-auth Key not found: $TA"
   exit
fi
echo "tls-auth Private Key found: $TA"

#Ready to make a new .opvn file - Start by populating with the

cat $DEFAULT > $ovpnName$FILEEXT

#Now, append the CA Public Cert
echo "<ca>" >> $ovpnName$FILEEXT
cat $cPath$CA | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' >> $ovpnName$FILEEXT
echo "</ca>" >> $ovpnName$FILEEXT

#Next append the client Public Cert
echo "<cert>" >> $ovpnName$FILEEXT
cat $kPath$NAME$CRT | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' >> $ovpnName$FILEEXT
echo "</cert>" >> $ovpnName$FILEEXT

#Then, append the client Private Key
echo "<key>" >> $ovpnName$FILEEXT
cat $kPath$NAME$KEY >> $ovpnName$FILEEXT
echo "</key>" >> $ovpnName$FILEEXT

#Finally, append the TA Private Key
echo "<tls-crypt>" >> $ovpnName$FILEEXT
cat $TA >> $ovpnName$FILEEXT
echo "</tls-crypt>" >> $ovpnName$FILEEXT

echo "Done! $ovpnName$FILEEXT Successfully Created."

