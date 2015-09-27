#!/bin/bash
bundle update && RACK_ENV=production bundle exec unicorn -c unicorn.rb
