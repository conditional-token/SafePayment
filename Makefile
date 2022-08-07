setup:
	@npm install -g truffle

compile:
	@truffle compile

deploy:
	@docker-compose up -d
	@truffle deploy

deploy-testnet:
	@truffle deploy --network ropsten

tests:
	@docker-compose up -d
	@truffle test