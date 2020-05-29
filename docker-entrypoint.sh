#!/usr/bin/env bash

set -e

if [[ -n "${DEBUG}" ]]; then
    set -x
fi

_gotpl() {
    if [[ -f "/etc/gotpl/$1" ]]; then
        gotpl "/etc/gotpl/$1" > "$2"
    fi
}

# Backwards compatibility for old env vars names.
_backwards_compatibility() {
    declare -A vars
    # vars[DEPRECATED]="ACTUAL"
    vars[NGINX_ALLOW_XML_ENDPOINTS]="NGINX_DRUPAL_ALLOW_XML_ENDPOINTS"
    vars[NGINX_STATIC_CONTENT_ACCESS_LOG]="NGINX_STATIC_ACCESS_LOG"
    vars[NGINX_STATIC_CONTENT_EXPIRES]="NGINX_STATIC_EXPIRES"
    vars[NGINX_STATIC_CONTENT_OPEN_FILE_CACHE]="NGINX_STATIC_OPEN_FILE_CACHE"
    vars[NGINX_STATIC_CONTENT_OPEN_FILE_CACHE_MIN_USES]="NGINX_STATIC_OPEN_FILE_CACHE_MIN_USES"
    vars[NGINX_STATIC_CONTENT_OPEN_FILE_CACHE_VALID]="NGINX_STATIC_OPEN_FILE_CACHE_VALID"
    vars[NGINX_XMLRPC_SERVER_NAME]="NGINX_DRUPAL_XMLRPC_SERVER_NAME"
    vars[NGINX_DRUPAL_TRACK_UPLOADS]="NGINX_TRACK_UPLOADS"

    for i in "${!vars[@]}"; do
        # Use value from old var if it's not empty and the new is.
        if [[ -n "${!i}" && -z "${!vars[$i]}" ]]; then
            export ${vars[$i]}="${!i}"
        fi
    done
}

process_templates() {
    _backwards_compatibility

    _gotpl "nginx.conf.tmpl" "/etc/nginx/nginx.conf"
    _gotpl "vhost.conf.tmpl" "/etc/nginx/conf.d/vhost.conf"
    _gotpl "includes/defaults.conf.tmpl" "/etc/nginx/defaults.conf"

    if [[ -n "${NGINX_MODSECURITY_ENABLED}" ]]; then
        _gotpl "includes/modsecurity.conf.tmpl" "/etc/nginx/modsecurity/main.conf"
    fi

    if [[ -n "${NGINX_VHOST_PRESET}" ]]; then
        _gotpl "presets/${NGINX_VHOST_PRESET}.conf.tmpl" "/etc/nginx/preset.conf"

        if [[ "${NGINX_VHOST_PRESET}" =~ ^drupal8|drupal7|drupal6|wordpress|php|data|resilience|perusio$ ]]; then
            _gotpl "includes/fastcgi.conf.tmpl" "/etc/nginx/fastcgi.conf"
            _gotpl "includes/upstream.php.conf.tmpl" "/etc/nginx/upstream.conf"
        elif [[ "${NGINX_VHOST_PRESET}" =~ ^http-proxy|django$ ]]; then
            if [[ -z "${NGINX_BACKEND_HOST}" && "${NGINX_VHOST_PRESET}" == "django" ]]; then
                export NGINX_BACKEND_HOST="python";
            fi

            _gotpl "includes/upstream.http-proxy.conf.tmpl" "/etc/nginx/upstream.conf"
        fi
    fi

    _gotpl "50x.html.tmpl" "/usr/share/nginx/html/50x.html"
}

sudo init_volumes

process_templates
exec_init_scripts

echo "Nginx version ${NGINX_VER} is running with preset ${NGINX_VHOST_PRESET} with a tag of ${DEPLOY_TAG}."

echo
echo
echo "Let's confirm we see /var/www/common filesystem and audit permissions."
echo
echo
echo Running as user ${NGINX_USER}
echo
echo
echo View system processes.
echo
echo
/bin/ps -ef
echo
echo
echo List attached filesystems
echo
echo
/bin/df -hi
echo "Let's audit /var/www/common filesystem and peak at permissions."
echo
echo
/bin/df -hi /var/www/common
echo
echo
if [[ ! -d "/var/www/common" ]]; then
    echo >&2 "/var/www/common/ not found...contact the AWS team to have them fix."
else
    echo "/var/www/common dir listing"
    ls -al /var/www/common
    echo
    echo
    echo "/var/www/common/files dir listing"
    ls -la /var/www/common/files | head -32
    echo
    echo
    if [[ ! -d "/var/www/common/tmp" ]]; then
            echo >&2 "/var/www/common/tmp not found...creating"
            mkdir -p /var/www/common/tmp
            chown -R ${user}:${group} /var/www/common/tmp
            chmod -R 777 /var/www/common/tmp
    else
        echo "/var/www/common/tmp dir listing"
        ls -la /var/www/common/tmp | head -32
    fi
    echo
    echo
    if [[ ! -d "/var/www/common/log" ]]; then
        echo >&2 "/var/www/common/log not found...creating"
        mkdir -p /var/www/common/log
    else
        echo "/var/www/common/log dir listing"
        ls -la /var/www/common/log | head -32
    fi
    echo
    echo
fi

if [[ "${1}" == "make" ]]; then
    exec "${@}" -f /usr/local/bin/actions.mk
else
    exec $@
fi
