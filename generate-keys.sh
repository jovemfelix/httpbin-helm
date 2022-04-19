DOMAIN=$1
MY_HOST=$2
# optional
APP=$3

echo "using: DOMAIN=[${DOMAIN}] MY_HOST=[${MY_HOST}] APP=[${APP}]"
FILE=${DOMAIN}.crt
if [[ -f "$FILE" ]]; then
    echo "$FILE exists."
else
# For this task you can use your favorite tool to generate certificates and keys. The commands below use openssl
# Create a root certificate and private key to sign the certificate for your services:
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj "/O=ca-organization/CN=${DOMAIN}" -keyout ${DOMAIN}.key -out ${DOMAIN}.crt
fi

# Create a certificate and a private key for nginx.example.com:
openssl req -out ${MY_HOST}.csr -newkey rsa:2048 -nodes -keyout ${MY_HOST}.key -subj "/O=${APP}/CN=${MY_HOST}"

openssl x509 -req -days 365 -CA ${DOMAIN}.crt -CAkey ${DOMAIN}.key -set_serial 0 -in ${MY_HOST}.csr -out ${MY_HOST}.crt