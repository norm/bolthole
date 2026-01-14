.PHONY: test flake8 pytest bats

test: flake8 pytest bats

flake8:
	flake8

pytest:
	pytest

bats:
	bats tests/
