FROM wordpress:latest

# Install additional PHP extensions if needed
RUN docker-php-ext-install pdo pdo_mysql

# Set permissions
RUN chown -R www-data:www-data /var/www/html
