FROM alpine:3.12
LABEL Maintainer="ThuanDH <thuandh@d2t.vn>" \
      Description="Image laravel with Nginx & PHP-FPM 7 based on Alpine Linux."

# Install packages
RUN apk --no-cache add php7 php7-fpm php7-bcmath php7-ctype php7-json php7-fileinfo \
    php7-mbstring php7-openssl php7-pdo_mysql php7-curl php7-pdo php7-tokenizer php7-xml \
    php7-opcache nginx curl runit openrc composer php7-simplexml php7-dom php7-xmlwriter php-fileinfo php7-gd php7-zip php7-xmlreader php7-session php7-gmp supervisor

# Configure nginx
COPY .docker/nginx.conf /etc/nginx/nginx.conf
ADD .docker/sites/*.conf /etc/nginx/conf.d/
# Remove default server definition
RUN rm /etc/nginx/conf.d/default.conf

# Configure PHP-FPM
COPY .docker/fpm-pool.conf /etc/php7/php-fpm.d/www.conf
COPY .docker/php.ini /etc/php7/conf.d/custom.ini

COPY .docker/supervisord.conf /etc/supervisord.conf
COPY .docker/supervisor.d /etc/supervisor.d

# Configure runit boot script
COPY .docker/boot.sh /sbin/boot.sh

RUN adduser -D -u 1000 -g 1000 -s /bin/sh www && \
    mkdir -p /var/www/html && \
    mkdir -p /var/cache/nginx && \
    chown -R www:www /var/www/html && \
    chown -R www:www /run && \
    chown -R www:www /var/lib/nginx && \
    chown -R www:www /var/log/nginx

COPY .docker/nginx.run /etc/service/nginx/run
COPY .docker/php.run /etc/service/php/run

RUN chmod +x /etc/service/nginx/run \
    && chmod +x /etc/service/php/run \
    && ls -al /var/www/html/

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
# RUN composer self-update 1.10.18
RUN composer clear-cache

COPY --chown=www . /var/www/html/laravel
RUN chmod 0777 -R /var/www/html/laravel/bootstrap
RUN chmod 0777 -R /var/www/html/laravel/storage

RUN cd /var/www/html/laravel && composer dump-autoload --no-scripts --optimize
RUN cd /var/www/html/laravel && php artisan cache:clear
RUN cd /var/www/html/laravel && php artisan config:clear
RUN cd /var/www/html/laravel && php artisan vendor:publish --tag=cms-public --force
RUN cd /var/www/html/laravel && php artisan cms:theme:assets:publish

# Expose the port nginx is reachable on
EXPOSE 80

# Let boot start nginx & php-fpm
#CMD ["sh", "/sbin/boot.sh"]
ENTRYPOINT ["sh", "/sbin/boot.sh"]

CMD ["sh", "supervisord -n -c /etc/supervisord.conf"]

HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1/fpm-ping