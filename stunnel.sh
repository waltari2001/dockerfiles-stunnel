export STUNNEL_CONF="/etc/stunnel/stunnel.conf"
export STUNNEL_DEBUG="${STUNNEL_DEBUG:-7}"
export STUNNEL_CLIENT="${STUNNEL_CLIENT:-no}"
export STUNNEL_VERIFY="${STUNNEL_VERIFY:-no}"
export STUNNEL_CAFILE="${STUNNEL_CAFILE:-/etc/ssl/certs/ca-certificates.crt}"
export STUNNEL_KEY="${STUNNEL_KEY:-/etc/stunnel/key.pem}"
export STUNNEL_CRT="${STUNNEL_CRT:-/etc/stunnel/cert.pem}"
export OUT="${OUT:-}"
export HOSTNAME=`hostname -f`

if [[ -z "${STUNNEL_SERVICE}" ]] || [[ -z "${STUNNEL_ACCEPT}" ]] || [[ -z "${STUNNEL_CONNECT}" ]]; then
    echo >&2 "one or more STUNNEL_SERVICE* values missing: "
    echo >&2 "  STUNNEL_SERVICE=${STUNNEL_SERVICE}"
    echo >&2 "  STUNNEL_ACCEPT=${STUNNEL_ACCEPT}"
    echo >&2 "  STUNNEL_CONNECT=${STUNNEL_CONNECT}"
    exit 1
fi

if [ -z ${SSL_HOSTNAME} ]; then 
    echo "Generate Self Signed certificate";
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ${STUNNEL_KEY} -out ${STUNNEL_CRT} \
      -subj "/C=US/ST=Georgia/L=Atlanta/O=GreenSky/OU=IT Department/CN=$HOSTNAME"
else 
    echo "Fetch SSL certificates from S3 bucket";
    aws s3 cp s3://xxxxxx/cf-certs/${SSL_HOSTNAME}.pem ${STUNNEL_CRT}
    aws s3 cp s3://xxxxxx/cf-certs/${SSL_HOSTNAME}.key ${STUNNEL_KEY}
    aws s3 cp s3://xxxxxx/cf-certs/CA.pem ${STUNNEL_CAFILE}
fi

cp -v ${STUNNEL_CAFILE} /usr/local/share/ca-certificates/stunnel-ca.crt
cp -v ${STUNNEL_CRT} /usr/local/share/ca-certificates/stunnel.crt
update-ca-certificates

unset SSarray SAarray SCarray STarray SCAarray SVarray
OUT=''
IFS=',' 
read -r -a SSarray <<< "$STUNNEL_SERVICE"
read -r -a SAarray <<< "$STUNNEL_ACCEPT"
read -r -a SCarray <<< "$STUNNEL_CLIENT"
read -r -a STarray <<< "$STUNNEL_CONNECT"
read -r -a SVarray <<< "$STUNNEL_VERIFY"
IFS=' '

for i in "${!SSarray[@]}"; do
  if [[ ${SVarray[$i]} == "yes" ]] || [[ ${SCarray[$i]} == "no" ]]
  then
    #OUT=$OUT"[${SSarray[$i]}]"$'\n'"accept = ${SAarray[$i]}"$'\n'"client = ${SCarray[$i]}"$'\n'"connect = ${STarray[$i]}"$'\n'"verifyChain = ${SVarray[$i]}"$'\n'"CAFile = /etc/stunnel/CA.crt"$'\n'"cert = /etc/stunnel/cert.pem"$'\n'"key = /etc/stunnel/key.pem"$'\n\n'
    OUT=$OUT"[${SSarray[$i]}]"$'\n'"accept = ${SAarray[$i]}"$'\n'"client = ${SCarray[$i]}"$'\n'"connect = ${STarray[$i]}"$'\n'"verifyChain = ${SVarray[$i]}"$'\n'"CAFile = ${STUNNEL_CAFILE}"$'\n'"cert = ${STUNNEL_CRT}"$'\n'"key = ${STUNNEL_KEY}"$'\n\n'
  else
    OUT=$OUT"[${SSarray[$i]}]"$'\n'"accept = ${SAarray[$i]}"$'\n'"client = ${SCarray[$i]}"$'\n'"connect = ${STarray[$i]}"$'\n'"verifyChain = ${SVarray[$i]}"$'\n\n'
  fi
done

if [[ ! -s ${STUNNEL_CONF} ]]; then
    cat /srv/stunnel/stunnel.conf.template | envsubst > ${STUNNEL_CONF}
fi

cat /etc/stunnel/stunnel.conf

exec "$@"
