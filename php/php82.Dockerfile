FROM php:8.2-fpm

COPY --from=composer/composer:latest-bin /composer /usr/bin/composer

ARG PUID=1000
ENV PUID ${PUID}
ARG PGID=1000
ENV PGID ${PGID}

RUN groupadd -g ${PGID} www
RUN useradd -u ${PUID} -g www -m www

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
    wget

RUN docker-php-ext-install pdo_pgsql mbstring zip exif pcntl
RUN docker-php-ext-configure gd --with-freetype --with-jpeg
RUN docker-php-ext-install gd
RUN pecl install redis \
    && docker-php-ext-enable redis

RUN apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
