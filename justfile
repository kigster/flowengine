set shell := ["bash", "-c"]

set dotenv-load

[no-exit-message]
recipes:
    @just --choose

test:
    @bundle exec rspec
    @bundle exec rubocop

# Setup Ruby dependencies
setup-ruby:
    #!/usr/bin/env bash
    [[ -d ~/.rbenv ]] || git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    [[ -d ~/.rbenv/plugins/ruby-build ]] || git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    cd ~/.rbenv/plugins/ruby-build && git pull && cd - >/dev/null
    echo -n "Checking if Ruby $(cat .ruby-version | tr -d '\n') is already installed..."
    rbenv install -s "$(cat .ruby-version | tr -d '\n')" >/dev/null 2>&1 && echo "yes" || echo "it wasn't, but now it is"
    bundle check || bundle install -j 12

setup: setup-ruby

cli DATA SCHEMA *ARGS:
    #!/usr/bin/env bash
    cd .. && ./cli validate-json -f {{DATA}} -s {{SCHEMA}}

validate-valid-json:
    ./cli validate-json -f VALID-JSON/sample.json -s VALID-JSON/schema.json

format:
    @bundle exec rubocop -a
    @bundle exec rubocop --auto-gen-config

lint: 
    @bundle exec rubocop

# Generates library documentation into ./doc folder and opens the browser
doc:
    @bundle exec rake doc
    @open ./doc/index.html

clean:
    @rm -rf pkg
    @rm -rf coverage

release:
    @bundle exec rake release

check-all: lint test

