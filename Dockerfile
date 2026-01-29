# Dockerfile for SuiteCRM
# Target: Azure Container Apps (Serverless)
# Self-contained, stateless, cloud-native image
#
# All build-time configuration is passed via ARG from docker-compose.yml,
# which reads from .env DOCKER_* variables.

# ============================================================================
# BUILD ARGUMENTS (from .env via docker-compose.yml)
# ============================================================================
# Using Bookworm variant for libc-client-dev availability (removed in Trixie)
ARG DOCKER_PHP_BASE_IMAGE=php:8.3-apache-bookworm
ARG DOCKER_PLATFORM=linux/amd64

# Use the base image from ARG
FROM --platform=${DOCKER_PLATFORM} ${DOCKER_PHP_BASE_IMAGE}

# Re-declare ARGs after FROM (they don't persist across FROM)
ARG DOCKER_SUITECRM_VERSION=8.8.0
ARG DOCKER_LABEL_MAINTAINER="TheBuzzMagazines DevOps"
ARG DOCKER_LABEL_DESCRIPTION="SuiteCRM Cloud-Native for Azure Container Apps"
ARG DOCKER_PHP_MEMORY_LIMIT=512M
ARG DOCKER_PHP_UPLOAD_MAX_FILESIZE=100M
ARG DOCKER_PHP_POST_MAX_SIZE=100M
ARG DOCKER_PHP_MAX_EXECUTION_TIME=300
ARG DOCKER_PHP_MAX_INPUT_TIME=300
ARG DOCKER_PHP_MAX_INPUT_VARS=10000
ARG DOCKER_OPCACHE_MEMORY=256
ARG DOCKER_OPCACHE_INTERNED_STRINGS=16
ARG DOCKER_OPCACHE_MAX_FILES=10000
ARG DOCKER_CONTAINER_PORT=80
ARG TZ=America/Chicago

# Labels from ARG
LABEL maintainer="${DOCKER_LABEL_MAINTAINER}"
LABEL description="${DOCKER_LABEL_DESCRIPTION}"
LABEL suitecrm.version="${DOCKER_SUITECRM_VERSION}"

# SuiteCRM version as ENV (available at runtime)
ENV SUITECRM_VERSION=${DOCKER_SUITECRM_VERSION}

# Install system dependencies including SSL certificates for Azure MySQL
# Using Bookworm base which has libc-client-dev (removed in Trixie)
RUN apt-get update && apt-get install -y \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libzip-dev \
    libicu-dev \
    libxml2-dev \
    libc-client-dev \
    libkrb5-dev \
    libldap2-dev \
    unzip \
    wget \
    curl \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Configure and install PHP extensions
# Note: soap and ldap are required by SuiteCRM pre-installation checks
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-configure ldap \
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
        pdo_mysql \
        soap \
        ldap

# Enable Apache mod_rewrite and headers
RUN a2enmod rewrite headers

# Set DocumentRoot to /var/www/html/public (SuiteCRM 8 requirement)
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Configure Apache to allow .htaccess overrides
RUN sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

# Configure Apache to listen on specified port (default 80, required for Azure Container Apps)
# Update both ports.conf AND VirtualHost to use the same port
RUN sed -i "s/Listen 80/Listen 0.0.0.0:${DOCKER_CONTAINER_PORT}/" /etc/apache2/ports.conf \
    && sed -i "s/<VirtualHost \*:80>/<VirtualHost *:${DOCKER_CONTAINER_PORT}>/" /etc/apache2/sites-available/000-default.conf

# PHP production configuration
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Custom PHP settings for SuiteCRM (using ARG values)
RUN echo "memory_limit = ${DOCKER_PHP_MEMORY_LIMIT}" > "$PHP_INI_DIR/conf.d/suitecrm.ini" \
    && echo "upload_max_filesize = ${DOCKER_PHP_UPLOAD_MAX_FILESIZE}" >> "$PHP_INI_DIR/conf.d/suitecrm.ini" \
    && echo "post_max_size = ${DOCKER_PHP_POST_MAX_SIZE}" >> "$PHP_INI_DIR/conf.d/suitecrm.ini" \
    && echo "max_execution_time = ${DOCKER_PHP_MAX_EXECUTION_TIME}" >> "$PHP_INI_DIR/conf.d/suitecrm.ini" \
    && echo "max_input_time = ${DOCKER_PHP_MAX_INPUT_TIME}" >> "$PHP_INI_DIR/conf.d/suitecrm.ini" \
    && echo "max_input_vars = ${DOCKER_PHP_MAX_INPUT_VARS}" >> "$PHP_INI_DIR/conf.d/suitecrm.ini" \
    && echo "date.timezone = ${TZ}" >> "$PHP_INI_DIR/conf.d/suitecrm.ini" \
    && echo "session.cookie_httponly = 1" >> "$PHP_INI_DIR/conf.d/suitecrm.ini" \
    && echo "session.cookie_secure = 1" >> "$PHP_INI_DIR/conf.d/suitecrm.ini" \
    && echo "session.use_strict_mode = 1" >> "$PHP_INI_DIR/conf.d/suitecrm.ini"

# OPcache settings for production (using ARG values)
RUN echo "opcache.enable=1" > "$PHP_INI_DIR/conf.d/opcache-recommended.ini" \
    && echo "opcache.memory_consumption=${DOCKER_OPCACHE_MEMORY}" >> "$PHP_INI_DIR/conf.d/opcache-recommended.ini" \
    && echo "opcache.interned_strings_buffer=${DOCKER_OPCACHE_INTERNED_STRINGS}" >> "$PHP_INI_DIR/conf.d/opcache-recommended.ini" \
    && echo "opcache.max_accelerated_files=${DOCKER_OPCACHE_MAX_FILES}" >> "$PHP_INI_DIR/conf.d/opcache-recommended.ini" \
    && echo "opcache.revalidate_freq=0" >> "$PHP_INI_DIR/conf.d/opcache-recommended.ini" \
    && echo "opcache.validate_timestamps=0" >> "$PHP_INI_DIR/conf.d/opcache-recommended.ini" \
    && echo "opcache.save_comments=1" >> "$PHP_INI_DIR/conf.d/opcache-recommended.ini" \
    && echo "opcache.fast_shutdown=1" >> "$PHP_INI_DIR/conf.d/opcache-recommended.ini"

# mysqli SSL settings for Azure MySQL
RUN echo "mysqli.default_ssl = true" > "$PHP_INI_DIR/conf.d/mysqli-ssl.ini"

# Download and install SuiteCRM
# Note: The SuiteCRM zip extracts directly without a wrapper directory
WORKDIR /var/www/html

RUN wget -q https://github.com/salesagility/SuiteCRM-Core/releases/download/v${SUITECRM_VERSION}/SuiteCRM-${SUITECRM_VERSION}.zip \
    && unzip -q SuiteCRM-${SUITECRM_VERSION}.zip \
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
# Variable names use SUITECRM_RUNTIME_MYSQL_* prefix for clarity
ENV SUITECRM_RUNTIME_MYSQL_HOST="localhost" \
    SUITECRM_RUNTIME_MYSQL_PORT="3306" \
    SUITECRM_RUNTIME_MYSQL_NAME="suitecrm" \
    SUITECRM_RUNTIME_MYSQL_USER="suitecrm" \
    SUITECRM_RUNTIME_MYSQL_PASSWORD="" \
    SUITECRM_RUNTIME_MYSQL_SSL_ENABLED="true" \
    SUITECRM_RUNTIME_MYSQL_SSL_VERIFY="true" \
    SUITECRM_SITE_URL="http://localhost" \
    SUITECRM_LOG_LEVEL="warning" \
    SUITECRM_INSTALLER_LOCKED="false" \
    TZ="UTC" \
    SKIP_DB_WAIT="false"

# Expose the container port
EXPOSE ${DOCKER_CONTAINER_PORT}

# Use custom entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Start Apache in foreground
CMD ["apache2-foreground"]
