#!/bin/bash
git pull
bundle install --without=migration development --no-color
RACK_ENV=production bundle exec unicorn -c unicorn.rb
