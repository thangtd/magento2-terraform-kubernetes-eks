# syntax = docker/dockerfile:1.2

FROM php:8.1-fpm-bullseye

ARG APP_ID=1000
RUN groupadd -g "$APP_ID" app \
  && useradd -g "$APP_ID" -u "$APP_ID" -d /var/www -s /bin/bash app

RUN mkdir -p /etc/nginx/html /var/www/html /sock \
  && chown -R app:app /etc/nginx /var/www /usr/local/etc/php/conf.d /sock

RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash -

RUN apt-get update && apt-get install -y \
  cron \
  default-mysql-client \
  git \
  gnupg \
  gzip \
  libbz2-dev \
  libfreetype6-dev \
  libicu-dev \
  libjpeg62-turbo-dev \
  libmagickwand-dev \
  libmcrypt-dev \
  libonig-dev \
  libpng-dev \
  libsodium-dev \
  libssh2-1-dev \
  libwebp-dev \
  libxslt1-dev \
  libzip-dev \
  lsof \
  mailutils \
  msmtp \
  nodejs \
  procps \
  vim \
  zip \
  && rm -rf /var/lib/apt/lists/*

RUN pecl channel-update pecl.php.net && pecl install \
  imagick \
  redis \
  ssh2-1.3.1 \
  xdebug \
  && pecl clear-cache \
  && rm -rf /tmp/pear

RUN docker-php-ext-configure \
  gd --with-freetype --with-jpeg --with-webp \
  && docker-php-ext-install \
  bcmath \
  bz2 \
  calendar \
  exif \
  gd \
  gettext \
  intl \
  mbstring \
  mysqli \
  opcache \
  pcntl \
  pdo_mysql \
  soap \
  sockets \
  sodium \
  sysvmsg \
  sysvsem \
  sysvshm \
  xsl \
  zip \
  && docker-php-ext-enable \
  imagick \
  redis \
  ssh2 \
  xdebug

RUN version=$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;") \
  && architecture=$(uname -m) \
  && curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/linux/$architecture/$version \
  && mkdir -p /tmp/blackfire \
  && tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp/blackfire \
  && mv /tmp/blackfire/blackfire-*.so $(php -r "echo ini_get ('extension_dir');")/blackfire.so \
  && rm -rf /tmp/blackfire /tmp/blackfire-probe.tar.gz

RUN curl -sS https://getcomposer.org/installer | \
  php -- --install-dir=/usr/local/bin --filename=composer

# Still need these config files for build and test purpose
COPY ./docker/phpfpm/conf/blackfire.ini $PHP_INI_DIR/conf.d/blackfire.ini
COPY ./docker/phpfpm/conf/msmtprc /etc/msmtprc
COPY ./docker/phpfpm/conf/php.ini $PHP_INI_DIR
COPY ./docker/phpfpm/conf/php-fpm.conf /usr/local/etc/
COPY ./docker/phpfpm/conf/www.conf /usr/local/etc/php-fpm.d/

# TODO: baking source code should be done during app deployment
COPY ./src/ /var/www/html

RUN --mount=type=secret,id=COMPOSER_AUTH_JSON,dst=/var/www/html/auth.json \
  composer install --no-interaction --working-dir=/var/www/html/

# set permissions
RUN cd /var/www/html/  \
  && find var generated vendor pub/static pub/media app/etc -type f -exec chmod g+w {} + \
  && find var generated vendor pub/static pub/media app/etc -type d -exec chmod g+ws {} + \
  && chown -R app:app . \
  && chmod u+x bin/magento

COPY ./docker/phpfpm/conf/config.php /var/www/html/app/etc/config.php

RUN cd /var/www/html/ \
  && bin/magento module:enable --all -c \
  && bin/magento setup:di:compile \
  && bin/magento setup:static-content:deploy --force -s standard --jobs=5

USER app:app

VOLUME /var/www

WORKDIR /var/www/html