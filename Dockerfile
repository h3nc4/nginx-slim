# Copyright (C) 2026  Henrique Almeida
# This file is part of NGINX Slim.
#
# NGINX Slim is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# NGINX Slim is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with NGINX Slim.  If not, see <https://www.gnu.org/licenses/>.

################################################################################

# NGINX and deps versions
ARG NGINX_VERSION="1.29.5"
ARG NGX_BROTLI_COMMIT="a71f9312"
ARG NGX_BROTLI_SHA256="1d21be34f3b7b6d05a8142945e59b3a47665edcdfe0f3ee3d3dbef121f90c08c"

################################################################################
# Nginx builder stage
FROM alpine:3.23@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659 AS nginx-builder
ARG NGINX_VERSION
ARG NGX_BROTLI_COMMIT
ARG NGX_BROTLI_SHA256

# Package installation
RUN apk add --no-cache gcc git gnupg libc-dev linux-headers make pcre2-dev pcre2-static brotli-dev brotli-static

# Download ngx_brotli module
ADD "https://github.com/google/ngx_brotli/archive/${NGX_BROTLI_COMMIT}.tar.gz" "ngx_brotli-${NGX_BROTLI_COMMIT}.tar.gz"

# Verify checksum, extract ngx_brotli and link system brotli to it
RUN echo "${NGX_BROTLI_SHA256}  ngx_brotli-${NGX_BROTLI_COMMIT}.tar.gz" | sha256sum -c - && \
  mkdir "ngx_brotli-${NGX_BROTLI_COMMIT}" && \
  tar -xf "ngx_brotli-${NGX_BROTLI_COMMIT}.tar.gz" --strip-components=1 -C "ngx_brotli-${NGX_BROTLI_COMMIT}" && \
  mkdir -p "ngx_brotli-${NGX_BROTLI_COMMIT}/deps/brotli/c/include" && \
  ln -s /usr/include/brotli "ngx_brotli-${NGX_BROTLI_COMMIT}/deps/brotli/c/include/brotli" && \
  ln -s /usr/lib "ngx_brotli-${NGX_BROTLI_COMMIT}/deps/brotli/c/lib"

# Download NGINX sources and signatures
ADD "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" .
ADD "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz.asc" .
ADD "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x43387825DDB1BB97EC36BA5D007C8D7C15D87369" "nginx-arut.key"
ADD "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xD6786CE303D9A9022998DC6CC8464D549AF75C0A" "nginx-pluknet.key"
ADD "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x7338973069ED3F443F4D37DFA64FD5B17ADB39A8" "nginx-sb.key"
ADD "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x13C82A63B603576156E30A4EA0EA981B66B0D967" "nginx-thresh.key"

# Verify GPG signatures and extract
RUN gpg --batch --yes --import <"nginx-arut.key" && \
  gpg --batch --yes --import <"nginx-pluknet.key" && \
  gpg --batch --yes --import <"nginx-sb.key" && \
  gpg --batch --yes --import <"nginx-thresh.key" && \
  gpg --batch --yes --verify "nginx-${NGINX_VERSION}.tar.gz.asc" "nginx-${NGINX_VERSION}.tar.gz"
RUN tar -xzf "nginx-${NGINX_VERSION}.tar.gz"

# Build Nginx
WORKDIR "/nginx-${NGINX_VERSION}"
RUN ./configure \
  --prefix="/run" \
  --pid-path="/run/nginx.pid" \
  --conf-path="/etc/nginx.conf" \
  --error-log-path="/dev/stderr" \
  --http-log-path="/dev/stdout" \
  --with-pcre \
  --add-module="../ngx_brotli-${NGX_BROTLI_COMMIT}" \
  --with-http_gzip_static_module \
  --with-http_v2_module \
  --with-http_realip_module \
  --with-http_stub_status_module \
  --with-threads \
  --with-file-aio \
  --without-http_gzip_module \
  --without-http_autoindex_module \
  --without-http_uwsgi_module \
  --without-http_scgi_module \
  --without-http_grpc_module \
  --without-http_memcached_module \
  --without-http_empty_gif_module \
  --without-http_browser_module \
  --without-http_userid_module \
  --without-http_ssi_module \
  --without-http_mirror_module \
  --without-http_split_clients_module \
  --without-http_geo_module \
  --without-http_map_module \
  --with-cc-opt="-O3 -fdata-sections -ffunction-sections -fomit-frame-pointer -flto" \
  --with-ld-opt="-static -Wl,--gc-sections -fuse-linker-plugin" && \
  make -j"$(nproc)"

# Minify nginx binary
RUN strip --strip-all "objs/nginx"

# Create root filesystem
RUN mkdir -p "/rootfs/run" && \
  mv "objs/nginx" "/rootfs/nginx" && \
  chown -R "65534:65534" "/rootfs/run"

# Copy and minify nginx config
COPY "nginx.conf" "/rootfs/nginx.conf"
RUN \
  # Remove comments and empty lines
  sed -E '/^[[:space:]]*#/d;/^[[:space:]]*$/d' "/rootfs/nginx.conf" | \
  # Remove all newlines to produce a single-line config
  tr -d '\n' | \
  # Compress consecutive spaces into a single space
  tr -s ' ' >"/rootfs/nginx.conf.min" && \
  mv "/rootfs/nginx.conf.min" "/rootfs/nginx.conf"

################################################################################
# Assemble runtime image
FROM scratch AS assemble

COPY --from=nginx-builder "/rootfs" "/"

################################################################################
# Final squashed image
FROM scratch AS final
ARG VERSION="dev"
ARG COMMIT_SHA="unknown"
ARG BUILD_DATE="unknown"

COPY --from=assemble "/" "/"
USER 65534:65534
ENTRYPOINT [ "/nginx" ]

LABEL org.opencontainers.image.title="NGINX Slim" \
  org.opencontainers.image.description="A minimal nginx container built from scratch" \
  org.opencontainers.image.authors="Henrique Almeida <me@h3nc4.com>" \
  org.opencontainers.image.vendor="Henrique Almeida" \
  org.opencontainers.image.licenses="GPL-3.0-or-later" \
  org.opencontainers.image.source="https://github.com/h3nc4/nginx-slim"
