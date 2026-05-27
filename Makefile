# Docker-first development — no local Ruby/Bundler required.
.PHONY: up down build logs bundle shell console migrate

up: build
	docker compose up -d

down:
	docker compose down

build:
	docker compose build web

logs:
	docker compose logs -f web

bundle:
	docker compose run --rm web bundle install

shell:
	docker compose run --rm web bash

console:
	docker compose run --rm web bundle exec rails console

migrate:
	docker compose run --rm web bundle exec rake db:migrate RAILS_ENV=production
