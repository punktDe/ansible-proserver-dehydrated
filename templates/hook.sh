#!/usr/bin/env bash

deploy_challenge() {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"

    if [ -f "{{ dehydrated.prefix.config|quote }}/acme-dns/${DOMAIN}.json" ]; then
        local username="$(jq -r '.username' {{ dehydrated.prefix.config|quote }}/acme-dns/${DOMAIN}.json)"
        local password="$(jq -r '.password' {{ dehydrated.prefix.config|quote }}/acme-dns/${DOMAIN}.json)"
        local subdomain="$(jq -r '.subdomain' {{ dehydrated.prefix.config|quote }}/acme-dns/${DOMAIN}.json)"
        local acme_dns="$(jq -r '.fulldomain|split(".")[1:]|join(".")' {{ dehydrated.prefix.config|quote }}/acme-dns/${DOMAIN}.json)"

        curl -s -S \
            -X POST \
            -H "X-Api-User: ${username}" \
            -H "X-Api-Key: ${password}" \
            -d '{"subdomain": "'"${subdomain}"'", "txt": "'"$3"'"}' \
            "https://${acme_dns}/update"
    fi
}

clean_challenge() {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"
}

deploy_cert() {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}" TIMESTAMP="${6}"

    {% if ansible_system == 'Linux' %}
    systemctl {{ dehydrated.httpd_service.state|regex_replace('^(reload|restart)ed$', '\\1')|quote }} {{ dehydrated.httpd_service.name|quote }}
    {% else %}
    if fgrep apache24_enable /etc/rc.conf | fgrep -i yes; then
        echo " + Hook: Restarting Apache..."
        /usr/local/etc/rc.d/apache24 graceful
    elif fgrep nginx_enable /etc/rc.conf | fgrep -i yes; then
        echo " + Hook: Restarting Nginx..."
        /usr/local/etc/rc.d/nginx reload
    else
        echo " + Neither Nginx nor Apache is enabled, thus no webserver is restarted. :)"
    fi
    {% endif %}
}

unchanged_cert() {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}"
}

invalid_challenge() {
    local DOMAIN="${1}" RESPONSE="${2}"
}

request_failure() {
    local STATUSCODE="${1}" REASON="${2}" REQTYPE="${3}" HEADERS="${4}"
}

generate_csr() {
    local DOMAIN="${1}" CERTDIR="${2}" ALTNAMES="${3}"
}

startup_hook() {
  :
}

exit_hook() {
  :
}

HANDLER="$1"; shift
if [[ "${HANDLER}" =~ ^(deploy_challenge|clean_challenge|deploy_cert|unchanged_cert|invalid_challenge|request_failure|generate_csr|startup_hook|exit_hook)$ ]]; then
  "$HANDLER" "$@"
fi
