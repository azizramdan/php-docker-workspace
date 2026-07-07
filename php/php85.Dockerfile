FROM php:8.5-fpm

COPY --from=composer/composer:latest-bin /composer /usr/bin/composer

ARG PUID=1000
ENV PUID ${PUID}
ARG PGID=1000
ENV PGID ${PGID}

RUN groupadd -g ${PGID} www
RUN useradd -u ${PUID} -g www -m www

ENV COMPOSER_HOME=/home/www/.config/composer
ENV COMPOSER_CACHE_DIR=/home/www/.cache/composer

RUN echo 'export PATH="$PATH:/home/www/.config/composer/vendor/bin"' >> /home/www/.bashrc

RUN apt-get update && apt-get install -y \
    build-essential \
	libpq-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
	libonig-dev \
    jpegoptim \
    optipng \
    pngquant \
    gifsicle \
    zip \
	libzip-dev \
    unzip \
    curl \
    wget \
    lsb-release \
    gnupg2 \
    git

RUN . /etc/os-release && \
    echo "deb [signed-by=/usr/share/keyrings/postgresql-keyring.gpg] http://apt.postgresql.org/pub/repos/apt/ ${VERSION_CODENAME}-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-keyring.gpg

RUN apt-get update && apt-get install -y postgresql-client-18

RUN docker-php-ext-install pdo_pgsql mbstring zip exif pcntl
RUN docker-php-ext-configure gd --with-freetype --with-jpeg
RUN docker-php-ext-install gd
RUN pecl install redis \
    && docker-php-ext-enable redis

RUN apt-get install -y libgmp-dev
RUN docker-php-ext-install gmp
RUN docker-php-ext-configure gmp

RUN docker-php-ext-install bcmath
RUN docker-php-ext-install pdo_mysql

RUN apt-get install -y libicu-dev
RUN docker-php-ext-install intl
RUN docker-php-ext-install pgsql
RUN docker-php-ext-install mysqli

RUN pecl install pcov \
    && docker-php-ext-enable pcov

RUN apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

USER www

RUN composer global require laravel/installer

# Use bash for the shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Create a script file sourced by both interactive and non-interactive bash shells
ENV BASH_ENV "/home/www/.bash_env"
RUN touch "${BASH_ENV}"
RUN echo '. "${BASH_ENV}"' >> ~/.bashrc

# Download and install nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.5/install.sh | PROFILE="${BASH_ENV}" bash
RUN echo node > .nvmrc
RUN nvm install
