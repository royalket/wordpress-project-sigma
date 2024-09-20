FROM wordpress:5.7-php7.4-apache

# Install additional PHP extensions
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libwebp-dev \
    && docker-php-ext-configure gd --with-jpeg --with-webp \
    && docker-php-ext-install gd

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Copy custom wp-config.php if you have one
# COPY wp-config.php /var/www/html/wp-config.php

# Set up volume for wp-content
VOLUME /var/www/html/wp-content