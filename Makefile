.PHONY: lint format build breaking

lint:
	buf lint

format:
	buf format -w

build:
	buf build

breaking:
	buf breaking --against 'https://github.com/PTLRepoHub/AddressIq-proto.git#branch=main'
