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

    for hook in {{ dehydrated.prefix.config|quote }}/hooks/deploy_challenge.d/*; do
        DOMAIN="$DOMAIN" TOKEN_FILENAME="$TOKEN_FILENAME" TOKEN_VALUE="$TOKEN_VALUE" "$hook" "$DOMAIN" "$TOKEN_FILENAME" "$TOKEN_VALUE" || :
    done
}

clean_challenge() {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"

    for hook in {{ dehydrated.prefix.config|quote }}/hooks/clean_challenge.d/*; do
        DOMAIN="$DOMAIN" TOKEN_FILENAME="$TOKEN_FILENAME" TOKEN_VALUE="$TOKEN_VALUE" "$hook" "$DOMAIN" "$TOKEN_FILENAME" "$TOKEN_VALUE" || :
    done
}

sync_cert() {
    local KEYFILE="${1}" CERTFILE="${2}" FULLCHAINFILE="${3}" CHAINFILE="${4}" REQUESTFILE="${5}"

    for hook in {{ dehydrated.prefix.config|quote }}/hooks/sync_cert.d/*; do
        KEYFILE="$KEYFILE" CERTFILE="$CERTFILE" FULLCHAINFILE="$FULLCHAINFILE" CHAINFILE="$CHAINFILE" REQUESTFILE="$REQUESTFILE" "$hook" "$KEYFILE" "$CERTFILE" "$FULLCHAINFILE" "$CHAINFILE" "$REQUESTFILE" || :
    done
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

    for hook in {{ dehydrated.prefix.config|quote }}/hooks/deploy_cert.d/*; do
        DOMAIN="$DOMAIN" KEYFILE="$KEYFILE" CERTFILE="$CERTFILE" FULLCHAINFILE="$FULLCHAINFILE" CHAINFILE="$CHAINFILE" TIMESTAMP="$TIMESTAMP" "$hook" "$DOMAIN" "$KEYFILE" "$CERTFILE" "$FULLCHAINFILE" "$CHAINFILE" "$TIMESTAMP" || :
    done
}

deploy_ocsp() {
    local DOMAIN="${1}" OCSPFILE="${2}" TIMESTAMP="${3}"

    for hook in {{ dehydrated.prefix.config|quote }}/hooks/deploy_ocsp.d/*; do
        DOMAIN="$DOMAIN" OCSPFILE="$OCSPFILE" TIMESTAMP="$TIMESTAMP" "$hook" "$DOMAIN" "$OCSPFILE" "$TIMESTAMP" || :
    done
}

unchanged_cert() {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}"

    for hook in {{ dehydrated.prefix.config|quote }}/hooks/unchanged_cert.d/*; do
        DOMAIN="$DOMAIN" KEYFILE="$KEYFILE" CERTFILE="$CERTFILE" FULLCHAINFILE="$FULLCHAINFILE" CHAINFILE="$CHAINFILE" "$hook" "$DOMAIN" "$KEYFILE" "$CERTFILE" "$FULLCHAINFILE" "$CHAINFILE" || :
    done
}

invalid_challenge() {
    local DOMAIN="${1}" RESPONSE="${2}"

    for hook in {{ dehydrated.prefix.config|quote }}/hooks/invalid_challenge.d/*; do
        DOMAIN="$DOMAIN" RESPONSE="$RESPONSE" "$hook" "$DOMAIN" "$RESPONSE" || :
    done
}

request_failure() {
    local STATUSCODE="${1}" REASON="${2}" REQTYPE="${3}" HEADERS="${4}"

    for hook in {{ dehydrated.prefix.config|quote }}/hooks/request_failure.d/*; do
        STATUSCODE="$STATUSCODE" REASON="$REASON" REQTYPE="$REQTYPE" HEADERS="$HEADERS" "$hook" "$STATUSCODE" "$REASON" "$REQTYPE" "$HEADERS" || :
    done
}

generate_csr() {
    local DOMAIN="${1}" CERTDIR="${2}" ALTNAMES="${3}"

    for hook in {{ dehydrated.prefix.config|quote }}/hooks/generate_csr.d/*; do
        DOMAIN="$DOMAIN" CERTDIR="$CERTDIR" ALTNAMES="$ALTNAMES" "$hook" "$DOMAIN" "$CERTDIR" "$ALTNAMES" || :
    done
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

        local protocol="$(jq -r '.protocol // "sftp"' "$config_file")"
        if [[ "$protocol" != "sftp" ]]; then
            continue
        fi

        local host="$(jq -r .host "$config_file")"
        local user="$(jq -r ".user // \"${cert}\"" "$config_file")"
        local path="$(jq -r ".path // empty" "$config_file")"
        local port="$(jq -r ".port // 22" "$config_file")"
        local opts
        IFS=$'\n' read -r -d '' -a opts < <(jq -r "(.opts // [])[]" "$config_file" && printf '\0')

        local public_key="$(jq -r .public_key "$config_file")"
        local public_key_file="$(mktemp)"
        cat <<< "$host $public_key" > "$public_key_file"

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
            sftp -q "${opts[@]}" \
                -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile="$public_key_file" -i "$private_key_file" \
                -P "$port" "${user}@${host}:${path}${file_basename}" "${!file_var}.cache"
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

    # custom hooks
    for hook in {{ dehydrated.prefix.config|quote }}/hooks/startup.d/*; do
        "$hook" || :
    done
}

exit_hook() {
  local ERROR="${1:-}"

    for hook in {{ dehydrated.prefix.config|quote }}/hooks/exit.d/*; do
        "$hook" || :
    done
}

HANDLER="$1"; shift
if [[ "${HANDLER}" =~ ^(deploy_challenge|clean_challenge|sync_cert|deploy_cert|deploy_ocsp|unchanged_cert|invalid_challenge|request_failure|generate_csr|startup_hook|exit_hook)$ ]]; then
  "$HANDLER" "$@"
fi
