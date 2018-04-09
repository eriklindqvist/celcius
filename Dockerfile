#https://blog.codeship.com/build-minimal-docker-container-ruby-apps/

FROM alpine:3.5
MAINTAINER Erik Lindqvist <erikjo82@gmail.com>

# Update and install all of the required packages.
# At the end, remove the apk cache
RUN apk update && \
    apk upgrade && \
    apk add linux-headers zlib-dev bash curl-dev ruby-dev build-base git && \
    apk add ruby ruby-io-console ruby-bundler ruby-dev && \
    apk add tzdata && \
    cp /usr/share/zoneinfo/Europe/Stockholm /etc/localtime && \
    echo "Europe/Stockholm" > /etc/timezone && \
    rm -rf /var/cache/apk/* && \
    mkdir /usr/app

WORKDIR /usr/app

COPY Gemfile /usr/app/
COPY Gemfile.lock /usr/app/
RUN bundle install --without=migration development --with=production --no-color

COPY . /usr/app

EXPOSE 4004
