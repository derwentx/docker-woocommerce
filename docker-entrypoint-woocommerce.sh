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
            WORDPRESS_ACTIVE_THEME
            WOOCOMMERCE_TEST_DATA
            WOOCOMMERCE_CONSUMER_KEY
            WOOCOMMERCE_CONSUMER_SECRET
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
            : "${WORDPRESS_URL:=http://localhost}"
            : "${WORDPRESS_SITE_TITLE:=API Test}"
            : "${WORDPRESS_ADMIN_USER:=admin}"
            : "${WORDPRESS_ADMIN_PASSWORD:=admin}"
            : "${WORDPRESS_ADMIN_EMAIL:=admin@example.com}"
            : "${SHELL:=/bin/sh}"

            # 
            as_web_user() {
                su $user --shell $SHELL -c "$*"
            }

            # Run the wp commands as web-user
            # This part has some inspiration from https://github.com/autopilotpattern/wordpress/blob/master/bin/prestart.sh
            as_web_user "wp core install --url=\"$WORDPRESS_SITE_URL\" \
              --title=\"$WORDPRESS_SITE_TITLE\" \
              --admin_user=\"$WORDPRESS_ADMIN_USER\" \
              --admin_password=\"$WORDPRESS_ADMIN_PASSWORD\" \
              --admin_email=\"$WORDPRESS_ADMIN_EMAIL\" "

            if [ -n "$WORDPRESS_ACTIVE_THEME" ]; then
                as_web_user "wp theme activate \"$WORDPRESS_ACTIVE_THEME\""
            fi

            # TODO: install plugins from env variable and ensure woocommerce
            as_web_user "wp plugin install woocommerce --activate"

            # Set up woocommerce
            as_web_user "wp wc tool run install_pages --user=\"$WORDPRESS_ADMIN_USER\""
            # Creates the woocommerce_api_keys table if it doesn't exist

            if [ -n $WOOCOMMERCE_CONSUMER_KEY ] && [ -n $WOOCOMMERCE_CONSUMER_SECRET ]; then

                as_web_user "wp eval \"WC_Install::install();\""

                as_web_user "wp eval '
                    global \$wpdb; 
                    echo \$wpdb->insert(
                        \$wpdb->prefix . \"woocommerce_api_keys\", 
                        array(
                            \"user_id\"=>1, 
                            \"permissions\"=>\"read_write\", 
                            \"consumer_key\"=> wc_api_hash( \"$WOOCOMMERCE_CONSUMER_KEY\" ), 
                            \"consumer_secret\"=> \"$WOOCOMMERCE_CONSUMER_SECRET\", 
                            \"truncated_key\" => substr( \"$WOOCOMMERCE_CONSUMER_SECRET\", -7 ) 
                        ), 
                        array( \"%d\", \"%s\", \"%s\",\"%s\",\"%s\", ) 
                    );'"
            fi
            



            if [ -n "$WOOCOMMERCE_TEST_DATA" ] && [ ! -f "sample_products.xml" ]; then
                as_web_user "wp plugin install wordpress-importer --activate"
                as_web_user "curl -OL https://raw.githubusercontent.com/woocommerce/woocommerce/master/sample-data/sample_products.xml"
                as_web_user "wp import sample_products.xml --authors=create"
            fi
        fi
    )
fi

exec "$@"
