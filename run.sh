#!/bin/bash
#bundle --no-color update --group=production &&
RACK_ENV=production bundle exec unicorn -c unicorn.rb
