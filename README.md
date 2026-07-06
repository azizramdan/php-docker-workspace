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

Then in the `.env` file (copy `.env.example` to `.env` first, it also holds the Postgres/MySQL credentials and ports used below)

```env
PUID=1000
PGID=1000
```

Currently supported PHP versions: `7.2`, `7.4`, `8.0`, `8.1`, `8.2`, `8.3`, `8.4`, `8.5`.

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

Currently, I use [Fedora Workstation](https://fedoraproject.org/workstation/), where NetworkManager doesn't use `dnsmasq` as its DNS backend by default, so it has to be enabled first:

```
# /etc/NetworkManager/conf.d/dnsmasq.conf

[main]
dns=dnsmasq
```

Then add the wildcard config:

```
# /etc/NetworkManager/dnsmasq.d/nginx-docker.conf

address=/.test/127.0.0.1
```

Restart NetworkManager to apply it:

```bash
sudo systemctl restart NetworkManager
```

Now, all domains with the `.test` extension will be directed to `127.0.0.1`, which will then be handled by `nginx` according to the domain pattern without needing to add entries to the `/etc/hosts` file.

### Working with Visual Studio Code

You can use the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension to integrate with the PHP container. Use [Attach to a running container](https://code.visualstudio.com/docs/devcontainers/attach-container) so that VSCode runs inside the container we have created.

Note that git is not installed inside the container by default, so you have to use git on the host, not in the container. If you still want to use git inside the container, add the installation to that PHP version's Dockerfile and rebuild (already done for `php82` and `php85` as an example), then follow this documentation [Working with Git](https://code.visualstudio.com/docs/devcontainers/containers#_working-with-git).

### PHP binary / executable path

If PHP is not installed on the host and you are not using [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) in VSCode, there will be an error in the `php.validate.executablePath` configuration, and you also won't be able to run `php`/`composer` directly from the host shell.

The `bash/` directory has wrapper scripts for that, working a bit like `nvm`:

- `bash/php` — forwards to `php` inside whichever `phpXX` container is currently selected (or the first one it finds running).
- `bash/composer` — same idea, but for `composer`.
- `bash/setphp <version>` — selects which PHP container `php`/`composer` should target for the current host, e.g. `setphp 84`.
- `bash/dcwd <service>` — `docker compose exec`s into a service and `cd`s into the matching path, based on where you are under `~/projects`.

Symlink the ones you want into your `PATH` and make them executable:

```bash
sudo ln -sf ~/projects/docker/bash/php /usr/local/bin/php
sudo ln -sf ~/projects/docker/bash/composer /usr/local/bin/composer
sudo ln -sf ~/projects/docker/bash/setphp /usr/local/bin/setphp
sudo chmod +x ~/projects/docker/bash/php ~/projects/docker/bash/composer ~/projects/docker/bash/setphp
```

Now, from the host:

```bash
php -v      # PHP 8.2.21 (cli), whichever phpXX container is running/selected

setphp 84
php -v      # PHP 8.4.x (cli)
```

The selection is cached per terminal (keyed by `tty`, in `/tmp/php_container_cache_*`), so switching with `setphp` doesn't require touching a symlink, and each open terminal can run a different PHP version at the same time — e.g. `setphp 84` in one tab and `setphp 85` in another, similar to `nvm use` per shell.

This also solves `php.validate.executablePath`, just point it at the wrapper:

```json
{
  "php.validate.executablePath": "/usr/local/bin/php"
}
```

## Miscellaneous

I also added services for PostgreSQL (14, 17, 18), MySQL 8.4, Redis, and bash aliases/helper scripts for development purposes. I aim to keep it simple and not include too many services.
