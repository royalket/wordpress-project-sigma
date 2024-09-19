FROM wordpress:php8.1-apache

# Install additional PHP extensions
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd mysqli pdo pdo_mysql zip

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Copy custom php.ini file
COPY php.ini $PHP_INI_DIR/conf.d/

# Set up WordPress
COPY wp-config.php /var/www/html/wp-config.php

# Set correct permissions
RUN chown -R www-data:www-data /var/www/html

# Use the default production configuration
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Expose port 80
EXPOSE 80

# Use the default WordPress entrypoint and CMD
