# NGINX Slim

A single-binary nginx image built from `scratch`. The published image is 2.8 MB. Its whole contents are the nginx binary and a default configuration. Nothing else is present, not a shell, a package manager or a libc, which leaves nginx as the only thing the image can execute.

Suited to serving static files or proxying, where the configuration arrives from outside and nothing has to be maintained inside the container.

## Configuration path

**nginx reads `/etc/nginx.conf`.** That is the path the binary was compiled with. A bare `docker run` with nothing mounted there stops at once:

```console
[emerg] 1#1: open() "/etc/nginx.conf" failed (2: No such file or directory)
```

A placeholder inside the image answers 200 on port 80. Replace it by mounting over that path, or by copying to it in a derived image.

## Serving static files

```Dockerfile
FROM h3nc4/nginx-slim:latest

COPY nginx.conf /etc/nginx.conf
COPY site/ /srv/
```

With a matching `nginx.conf`:

```nginx
worker_processes auto;
daemon off;

events {
  worker_connections 1024;
}

http {
  server {
    listen 8080;
    root /srv;
    index index.html;
  }
}
```

`daemon off;` is required. nginx is PID 1 here, and a master that daemonises exits immediately and takes the container with it.

## Mounting a configuration instead

```sh
docker run --rm -p 8080:8080 \
  -v "${PWD}/nginx.conf:/etc/nginx.conf:ro" \
  h3nc4/nginx-slim:latest
```

## Image defaults

| Detail | Value |
| --- | --- |
| Configuration | `/etc/nginx.conf` |
| User | `65534:65534`, set in the image |
| Writable path | `/run`, owned by that uid |
| Error log | stderr |
| Access log | stdout |

**Listen above 1024, or grant the capability.** The process runs as `65534`, so `listen 80;` needs `NET_BIND_SERVICE` unless the host sets `net.ipv4.ip_unprivileged_port_start=0`.

**Anything nginx writes belongs under `/run`.** A proxy cache, a temp path or a pid file anywhere else fails, because no other directory is writable.

Comments and blank lines are stripped from the built-in configuration during the build and the rest is collapsed onto one line. A mounted or copied file is read as written.

## Building

```sh
docker build -t nginx-slim .
```

The build fetches the nginx release and verifies its signature against the upstream keys. The compile enables PCRE, Brotli, gzip static, HTTP/2, realip, stub status and threads.

## License

<!-- vale off -->

NGINX Slim is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

NGINX Slim is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with NGINX Slim. If not, see <https://www.gnu.org/licenses/>.
