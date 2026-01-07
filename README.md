# NGINX Slim

A single binary NGINX Docker image built with static binaries for reduced size and improved security.

This image is optimized for serving static content behind a reverse proxy.

## Minimal Example

To use NGINX Slim, create a `Dockerfile` in your project directory similar to the following:

```Dockerfile
FROM h3nc4/nginx-slim:latest

COPY ./nginx.conf /nginx.conf
COPY ./static /<Your static files directory>
```

## License

NGINX Slim is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

NGINX Slim is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with NGINX Slim. If not, see <https://www.gnu.org/licenses/>.
