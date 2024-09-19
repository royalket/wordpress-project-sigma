﻿FROM wordpress:latest

# Install additional PHP extensions in docker
RUN apt-get update && apt-get install -y \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd mysqli opcache

# Copy custom php.ini file
COPY php.ini $PHP_INI_DIR/conf.d/custom.ini

# Copy wp-content directory
COPY wp-content /var/www/html/wp-content

# Set permissions
RUN chown -R www-data:www-data /var/www/html/wp-content

# Expose port 80
EXPOSE 80

# Use the default WordPress entrypoint
CMD ["apache2-foreground"]

