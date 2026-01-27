# Dockerfile for SuiteCRM 8.8.0
# Target: Azure Container Apps (Serverless)
# Self-contained, stateless, cloud-native image
FROM --platform=linux/amd64 php:8.3-apache

LABEL maintainer="TheBuzzMagazines DevOps"
LABEL description="SuiteCRM 8.8.0 Cloud-Native for Azure Container Apps"

# SuiteCRM version
ENV SUITECRM_VERSION=8.8.0

# Install system dependencies including SSL certificates for Azure MySQL
RUN apt-get update && apt-get install -y \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libzip-dev \
    libicu-dev \
    libxml2-dev \
    libc-client-dev \
    libkrb5-dev \
    unzip \
    wget \
    curl \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Configure and install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-install -j$(nproc) \
        mysqli \
        gd \
        zip \
        intl \
        xml \
        opcache \
        imap \
        bcmath \
        pdo \
        pdo_mysql

# Enable Apache mod_rewrite and headers
RUN a2enmod rewrite headers

# Set DocumentRoot to /var/www/html/public (SuiteCRM 8 requirement)
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Configure Apache to allow .htaccess overrides
RUN sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

# Configure Apache to listen on port 80 (required for Azure Container Apps)
RUN sed -i 's/Listen 80/Listen 0.0.0.0:80/' /etc/apache2/ports.conf

# PHP production configuration
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Custom PHP settings for SuiteCRM
RUN { \
    echo 'memory_limit = 512M'; \
    echo 'upload_max_filesize = 100M'; \
    echo 'post_max_size = 100M'; \
    echo 'max_execution_time = 300'; \
    echo 'max_input_time = 300'; \
    echo 'max_input_vars = 10000'; \
    echo 'date.timezone = UTC'; \
    echo 'session.cookie_httponly = 1'; \
    echo 'session.cookie_secure = 1'; \
    echo 'session.use_strict_mode = 1'; \
    } > "$PHP_INI_DIR/conf.d/suitecrm.ini"

# OPcache settings for production
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.interned_strings_buffer=16'; \
    echo 'opcache.max_accelerated_files=10000'; \
    echo 'opcache.revalidate_freq=0'; \
    echo 'opcache.validate_timestamps=0'; \
    echo 'opcache.save_comments=1'; \
    echo 'opcache.fast_shutdown=1'; \
    } > "$PHP_INI_DIR/conf.d/opcache-recommended.ini"

# mysqli SSL settings for Azure MySQL
RUN { \
    echo 'mysqli.default_ssl = true'; \
    } > "$PHP_INI_DIR/conf.d/mysqli-ssl.ini"

# Download and install SuiteCRM
WORKDIR /var/www/html

RUN wget -q https://github.com/salesagility/SuiteCRM-Core/releases/download/v${SUITECRM_VERSION}/SuiteCRM-${SUITECRM_VERSION}.zip \
    && unzip -q SuiteCRM-${SUITECRM_VERSION}.zip \
    && mv SuiteCRM-${SUITECRM_VERSION}/* . \
    && mv SuiteCRM-${SUITECRM_VERSION}/.[!.]* . 2>/dev/null || true \
    && rmdir SuiteCRM-${SUITECRM_VERSION} \
    && rm SuiteCRM-${SUITECRM_VERSION}.zip

# Create directories for persistent data
RUN mkdir -p /var/www/html/public/legacy/upload \
    && mkdir -p /var/www/html/public/legacy/custom \
    && mkdir -p /var/www/html/public/legacy/cache

# Set base permissions (entrypoint will handle mounted volumes)
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 775 /var/www/html/public/legacy/upload \
    && chmod -R 775 /var/www/html/public/legacy/custom \
    && chmod -R 775 /var/www/html/public/legacy/cache

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Set working directory
WORKDIR /var/www/html

# Environment variables with defaults (override in Azure Container Apps)
ENV DATABASE_HOST="localhost" \
    DATABASE_PORT="3306" \
    DATABASE_NAME="suitecrm" \
    DATABASE_USER="suitecrm" \
    DATABASE_PASSWORD="" \
    DATABASE_SSL_ENABLED="true" \
    DATABASE_SSL_VERIFY="true" \
    SUITECRM_SITE_URL="http://localhost" \
    SUITECRM_LOG_LEVEL="warning" \
    SUITECRM_INSTALLER_LOCKED="false" \
    TZ="UTC" \
    SKIP_DB_WAIT="false"

# Expose port 80
EXPOSE 80

# Use custom entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Start Apache in foreground
CMD ["apache2-foreground"]
