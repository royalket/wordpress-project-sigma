# Use the official WordPress image as a parent image
FROM wordpress:latest

# Install required PHP extensions and other dependencies
RUN set -ex; \
    \
    apt-get update; \
    apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libzip-dev \
    ; \
    \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-install -j "$(nproc)" \
        gd \
        opcache \
        zip \
    ; \
    \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# Install the Google Cloud Storage WordPress plugin
RUN apt-get update && apt-get install -y unzip
RUN curl -O https://downloads.wordpress.org/plugin/wp-stateless.4.0.4.zip \
    && unzip wp-stateless.4.0.4.zip -d /usr/src/wordpress/wp-content/plugins/ \
    && rm wp-stateless.4.0.4.zip

# Copy custom wp-config.php
COPY wp-config.php /usr/src/wordpress/wp-config.php

# Set up PHP configuration
RUN { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=2'; \
        echo 'opcache.fast_shutdown=1'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini

# Use the default WordPress entrypoint
CMD ["apache2-foreground"]