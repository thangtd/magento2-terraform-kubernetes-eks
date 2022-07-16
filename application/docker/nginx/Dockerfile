FROM nginx:1.18-alpine

ARG APP_ID=1000

RUN addgroup -g "$APP_ID" app \
 && adduser -G app -u "$APP_ID" -h /var/www -s /bin/bash -S app
RUN touch /var/run/nginx.pid
RUN mkdir -p /sock

RUN apk add --no-cache \
  curl \
  nss-tools \
  openssl

ARG TARGETARCH

RUN cd /usr/local/bin/ \
  && curl -L https://github.com/FiloSottile/mkcert/releases/download/v1.4.3/mkcert-v1.4.3-linux-$TARGETARCH -o mkcert \
  && chmod +x mkcert

RUN mkdir -p /etc/nginx/html /var/www/html

# TODO: should be replaced by k8s configmap
COPY ./docker/nginx/conf/nginx.conf /etc/nginx/
COPY ./docker/nginx/conf/default.conf /etc/nginx/conf.d/

# TODO: source code needs to be baked during app deployment
COPY ./src/ /var/www/html

RUN chown -R app:app /etc/nginx /var/www /var/cache/nginx /var/run/nginx.pid /sock

USER app:app

EXPOSE 8443

VOLUME /var/www

WORKDIR /var/www/html