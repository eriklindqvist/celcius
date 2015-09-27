#https://blog.codeship.com/build-minimal-docker-container-ruby-apps/

FROM alpine:edge
MAINTAINER Erik Lindqvist <erikjo82@gmail.com>

# Update and install all of the required packages.
# At the end, remove the apk cache
RUN apk update && \
    apk upgrade && \
    apk add bash curl-dev ruby-dev build-base git && \
    apk add ruby ruby-io-console ruby-bundler ruby-dev ruby-raindrops && \
    rm -rf /var/cache/apk/*

RUN mkdir /usr/app
WORKDIR /usr/app

COPY Gemfile /usr/app/
COPY Gemfile.lock /usr/app/
RUN bundle update

COPY . /usr/app
