#!/usr/bin/env bash
set -e -u -o pipefail
shopt -s nullglob

deploy_challenge() {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"

    if [[ -f {{ dehydrated.prefix.config|quote }}/acme-dns/"${DOMAIN}".json ]]; then
        local username="$(jq -r '.username' {{ dehydrated.prefix.config|quote }}/acme-dns/"${DOMAIN}".json)"
        local password="$(jq -r '.password' {{ dehydrated.prefix.config|quote }}/acme-dns/"${DOMAIN}".json)"
        local subdomain="$(jq -r '.subdomain' {{ dehydrated.prefix.config|quote }}/acme-dns/"${DOMAIN}".json)"
        local acme_dns="$(jq -r '.fulldomain|split(".")[1:]|join(".")' {{ dehydrated.prefix.config|quote }}/acme-dns/"${DOMAIN}".json)"

        curl -s -S \
            -X POST \
            -H "X-Api-User: ${username}" \
            -H "X-Api-Key: ${password}" \
            -d '{"subdomain": "'"${subdomain}"'", "txt": "'"$3"'"}' \
            "https://${acme_dns}/update"
    fi
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

_get_cert_enddate() {
    local enddate="$(openssl x509 -in "$1" -enddate -noout | sed -E 's/^[^=]+=(.*)$/\1/')"
    {% if ansible_system == 'Linux' %}
    date -d "$enddate" +%s
    {% else %}
    date -j -f "%b %d %T %Y %Z" "$enddate" +%s
    {% endif %}
}

startup_hook() {
    # acme-cache
    for config_file in {{ dehydrated.prefix.config|quote }}/acme-cache/*.json; do
        local cert="$config_file"; cert="${cert##*/}"; cert="${cert%.json}"

        local protocol="$(jq -r .protocol "$config_file")"
        if [[ "$protocol" != "sftp" ]]; then
            continue
        fi

        local host="$(jq -r .host "$config_file")"
        local user="$(jq -r .user "$config_file")"
        local path="$(jq -r .path "$config_file")"

        local public_key="$(jq -r .public_key "$config_file")"
        local public_key_file="$(mktemp)"
        cat <<< "$public_key" > "$public_key_file"

        local private_key="$(jq -r .private_key "$config_file")"
        local private_key_file="$(mktemp)"
        cat <<< "$private_key" > "$private_key_file"

        local cert_dir={{ dehydrated.prefix.certs|quote }}/"$cert"
        local cert_file="${cert_dir}/cert.pem"
        local chain_file="${cert_dir}/chain.pem"
        local fullchain_file="${cert_dir}/fullchain.pem"
        local privkey_file="${cert_dir}/privkey.pem"

        local umask="$(umask)"
        umask 0077
        mkdir -p -- "${cert_dir}"
        umask 0177
        for file_var in cert_file chain_file fullchain_file privkey_file; do
            local file_basename="$(basename -- "${!file_var}")"
            sftp -q \
                -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile="$public_key_file" -i "$private_key_file" \
                "${user}@${host}:${path}${file_basename}" "${!file_var}.cache"
        done
        umask "$umask"

        if [[ ! -f "$cert_file" ]] || [[ "$(_get_cert_enddate "${cert_file}.cache")" -gt "$(_get_cert_enddate "${cert_file}")" ]]; then
            for file_var in cert_file chain_file fullchain_file privkey_file; do
                if [[ -L "${!file_var}" ]]; then
                    rm -- "${!file_var}"
                fi
                mv -- "${!file_var}.cache" "${!file_var}"
            done
            deploy_cert "$cert" "$privkey_file" "$cert_file" "$fullchain_file" "$chain_file" 0
        else
            for file_var in cert_file chain_file fullchain_file privkey_file; do
                rm -- "${!file_var}.cache"
            done
        fi
    done
}

HANDLER="$1"; shift
if [[ "${HANDLER}" =~ ^(deploy_challenge|deploy_cert|startup_hook)$ ]]; then
  "$HANDLER" "$@"
fi
