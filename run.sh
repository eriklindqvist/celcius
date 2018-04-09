#!/bin/bash
RACK_ENV=production bundle exec unicorn -c unicorn.rb
