setup:
	@npm install -g truffle

compile:
	@truffle compile

deploy:
	@docker-compose up -d
	@truffle deploy

tests:
	@docker-compose up -d
	@truffle test