.PHONY: setup test lint tf-init tf-check plan destroy

setup:
	python3 -m venv .venv
	.venv/bin/pip install -r requirements-dev.txt

test:
	.venv/bin/pytest -q

lint:
	.venv/bin/ruff check src producer tests

tf-init:
	terraform -chdir=infra init

tf-check:
	terraform -chdir=infra fmt -check
	terraform -chdir=infra validate

plan:
	terraform -chdir=infra plan -out=stock-analytics.tfplan

destroy:
	terraform -chdir=infra destroy

