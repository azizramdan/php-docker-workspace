# My personal PHP Docker workspace

Almost all of my work uses Laravel with various PHP versions, requiring me to frequently switch PHP versions or even run them simultaneously. This is my personal minimalist PHP Docker workspace.

## Short story

Most of my work involves [Laravel](https://laravel.com) and [Nuxt](https://nuxt.com/) with different versions of PHP and Node.js. In Node.js, we can use [nvm](https://github.com/nvm-sh/nvm)/[nvm-windows](https://github.com/coreybutler/nvm-windows) to manage versions, but I haven't found a good tool for PHP.

I know we can use docker for each project, but I think it consumes too many resources. I have used Laragon on Windows with custom configuration, check this [arlab-dev/laragon-multi-php](https://github.com/arlab-dev/laragon-multi-php). I have also used [Laradock](https://laradock.io/). This configuration is inspired by both Laragon and Laradock.

## How does it work?

### CLI

In the `php` directory, there are various PHP docker images with `php-fpm` as the base image. Each image requires a user and group ID, set in the `.env` file.

```bash
# check from passwd
cat /etc/passwd | grep $USER

# or
echo $UID && echo $GID
```

Then in the `.env` file

```env
PUID=1000
PGID=1000
```

Each image will be created as a service in docker compose. Each PHP service mounts a volume to the location where all projects are located based on the `PROJECT_PATH` environment variable; this is inspired by Laradock [Multiple Projects](https://laradock.io/getting-started/#B).

Project location on the host

    ├── home
    │   ├── arlab
    │   │   ├── projects
    │   │   │   ├── foo
    │   │   │   ├── bar
    │   │   │   ├── foo-bar
    │   │   │   └── ...

Then in the `.env` file

```env
PROJECT_PATH=~/projects
```

Now we can enter the PHP container and access each project in `/projects` inside the container.

```bash
docker compose exec php82 bash
cd /projects/foo
php artisan -V
```

### Web

In the `nginx/conf.d` directory, there are nginx configurations for each PHP version. The concept is to access projects using a pattern based on the project's name.

`http://foo-lv82.test` will point to the `foo` project using PHP version `8.2`.

`http://foo-bar-lv72.test` will point to the `foo-bar` project using PHP version `7.2`.

I use the pattern `*-version.test`, where `lv82` means a Laravel project using PHP version 8.2, and it will point to the root `/project/{directory}/public`.

Some of my projects use different directory structures, for example, `foo-lv82-be.test` will point to the root `/projects/{directory}/backend/public`.

To access these domains, add them to the `/etc/hosts` file.

```
127.0.0.1   foo-lv82.test
127.0.0.1   foo-bar-lv72.test
127.0.0.1   foo-lv82-be.test
```

Now, access these domains from the browser. This concept is inspired by Laragon, although it works differently; in Laragon, each project's virtual host configuration is generated automatically.

### Wildcard DNS

Whenever there is a new project, it must be added to the DNS in the `/etc/hosts` file. In Laragon, everything is automatically generated, both the virtual host configuration and the DNS entry in `/etc/hosts`. To achieve this, I use `dnsmasq`, although it works differently from Laragon.

Currently, I use [EndeavourOS](https://endeavouros.com/) which has dnsmasq pre-installed, so I simply add this configuration:

```
# /etc/NetworkManager/dnsmasq.d/nginx-docker.conf

address=/.test/127.0.0.1
```

Now, all domains with the `.test` extension will be directed to `127.0.0.1`, which will then be handled by `nginx` according to the domain pattern without needing to add entries to the `/etc/hosts` file.

### Working with Visual Studio Code

I use the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension to integrate with the PHP container. Use [Attach to a running container](https://code.visualstudio.com/docs/devcontainers/attach-container) so that VSCode runs inside the container we have created.

### PHP binary / executable path

If PHP is not installed on the host and you are not using [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) in VSCode, there will be an error in the `php.validate.executablePath` configuration.

Create a bash file to access the PHP binary inside the container for each PHP version:

```bash
# /usr/local/bin/php82

#!/bin/bash
docker exec -it docker-php82-1 php $@
```

Then add execution permissions:

```bash
sudo chmod +x /usr/local/bin/php82
```

Now, from the host, you can access it like this:

```bash
php82 -v
php80 -v
```

You can also create a symlink to access it with the `php` keyword:

```bash
sudo ln -sf /usr/local/bin/php82 /usr/local/bin/php
```

So you can access:

```bash
php -v # PHP 8.2.21 (cli)
```

If you want to change the version, just create a symlink for another version. Unfortunately, with this method, you can only activate one version at a time. I will update it (if I have time) to work like nvm, which can change the version only in the active terminal session.

```bash
sudo ln -sf /usr/local/bin/php80 /usr/local/bin/php
php -v # PHP 8.0.0 (cli)

sudo ln -sf /usr/local/bin/php74 /usr/local/bin/php
php -v # PHP 7.4.0 (cli)
```

Now `php.validate.executablePath` is solved. If a project uses a different PHP version, you can either change the symlink or update the `php.validate.executablePath` configuration to use another version.

```json
{
  "php.validate.executablePath": "/usr/local/bin/php80"
}
```

## Miscellaneous

I also added services for Postgres, Redis, and bash aliases for development purposes. I aim to keep it simple and not include too many services.

