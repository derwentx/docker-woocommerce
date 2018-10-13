# Woocommerce Docker
# PHP Docker for Woocommerce on Steroids
# Forked from https://github.com/julianxhokaxhiu/docker-woocommerce
#
# VERSION 0.2

FROM wordpress:php7.1-apache
MAINTAINER Derwent McElhinney <derwent [at] laserphile [dot] com>
LABEL Description="PHP Docker for Woocommerce on Steroids" Vendor="Derwent McElhinney" Version="0.2"


# enable extra Apache modules
RUN a2enmod rewrite \
  && a2enmod headers

########
# install the PHP extensions we need
########
# These lines are already handled by wordpress and are not needed
#   apt-get install -y --no-install-recommends \
#       libjpeg-dev \
#       libpng-dev \
#   libjpeg-dev
#   libpng-dev
#   docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr; \
#   docker-php-ext-install gd mysqli opcache zip; \

RUN set -ex; \
        \
        apt-get update; \
        apt-get install -y --no-install-recommends \
        libxml2-dev \
        libxslt-dev \
        libgraphicsmagick1-dev \
        graphicsmagick \
        less \
        && rm -rf /var/lib/apt/lists/* \
        && docker-php-ext-install json pdo pdo_mysql gettext exif calendar soap xsl sockets wddx

# install APCu from PECL
RUN pecl -vvv install apcu && docker-php-ext-enable apcu

# install GMagick from PECL
RUN pecl -vvv install gmagick-beta && docker-php-ext-enable gmagick

# Download WordPress CLI
RUN curl -L "https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar" > /usr/bin/wp \
    && chmod +x /usr/bin/wp

########
# set recommended PHP.ini settings
########
# Already handled by wordpress Dockerfile
# see https://secure.php.net/manual/en/opcache.installation.php
# RUN { \
#     echo 'opcache.memory_consumption=128'; \
#     echo 'opcache.interned_strings_buffer=8'; \
#     echo 'opcache.max_accelerated_files=4000'; \
#     echo 'opcache.revalidate_freq=60'; \
#     echo 'opcache.fast_shutdown=1'; \
#     echo 'opcache.enable_cli=1'; \
#   } > /usr/local/etc/php/conf.d/opcache-recommended.ini

# increase upload size
# see http://php.net/manual/en/ini.core.php
RUN { \
    echo "upload_max_filesize = 25M"; \
    echo "post_max_size = 50M"; \
  } > /usr/local/etc/php/conf.d/uploads.ini

# Iron the security of the Docker
RUN { \
    echo "expose_php = Off"; \
    echo "display_startup_errors = off"; \
    echo "display_errors = off"; \
    echo "html_errors = off"; \
    echo "log_errors = off"; \
    echo "ignore_repeated_errors = off"; \
    echo "ignore_repeated_source = off"; \
    echo "report_memleaks = on"; \
    echo "track_errors = on"; \
    echo "docref_root = 0"; \
    echo "docref_ext = 0"; \
    echo "error_reporting = -1"; \
    echo "log_errors_max_len = 0"; \
  } > /usr/local/etc/php/conf.d/security.ini

RUN { \
    echo "ServerSignature Off"; \
    echo "ServerTokens Prod"; \
    echo "TraceEnable off"; \
  } >> /etc/apache2/apache2.conf

# Override docker-entrypoint.sh provided by wordpress
COPY docker-entrypoint-woocommerce.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint-woocommerce.sh"]

# Remove the line exec "$@" from docker-entrypoint.sh so it can be wrapped
RUN sed -i $'s/^exec "$@"/# removed exec/g' /usr/local/bin/docker-entrypoint.sh
