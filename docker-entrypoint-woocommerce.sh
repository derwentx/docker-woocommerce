#!/bin/bash
set -euo pipefail

# This wraps around the docker-entrypoint.sh provided by the wordpress image
# https://github.com/docker-library/wordpress/blob/master/docker-entrypoint.sh



if [[ "$1" == apache2* ]] || [ "$1" == php-fpm ]; then
    # use the original docker entrypoint to provision wordpress files
    # no longer necessary if we are sourcing the file anyway
    # exec "docker-entrypoint.sh $@"


    # Use a subprocess to source the file_env() function from docker-entrypoint.sh
    (
        set -ex
        # Clear arguments so that it is not set up twice
        # set --
        source "docker-entrypoint.sh"
        envs=(
            WORDPRESS_SITE_URL
            WORDPRESS_SITE_TITLE
            WORDPRESS_ADMIN_USER
            WORDPRESS_ADMIN_PASSWORD
            WORDPRESS_ADMIN_EMAIL
        )
        haveConfig=
        for e in "${envs[@]}"; do
            file_env "$e"
            if [ -z "$haveConfig" ] && [ -n "${!e}" ]; then
                haveConfig=1
            fi
        done

        # only install wp if we have environment-supplied configuration values
        if [ "$haveConfig" ]; then
            : "${WORDPRESS_SITE_URL:=http://localhost}"
            : "${WORDPRESS_SITE_TITLE:=API Test}"
            : "${WORDPRESS_ADMIN_USER:=admin}"
            : "${WORDPRESS_ADMIN_PASSWORD:=admin}"
            : "${WORDPRESS_ADMIN_EMAIL:=admin@example.com}"

            # Run the wp command as www-data
            su --shell="${SHELL:='/bin/sh'}" -c "wp core install --url=\"$WORDPRESS_SITE_URL\" --title=\"$WORDPRESS_SITE_TITLE\" --admin_user=\"$WORDPRESS_ADMIN_USER\" --admin_password=\"$WORDPRESS_ADMIN_PASSWORD\" --admin_email=\"$WORDPRESS_ADMIN_EMAIL\"" www-data
        fi
    )
fi

exec "$@"
