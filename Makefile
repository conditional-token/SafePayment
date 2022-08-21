include .env
export

setup:
	@npm install -g truffle
	@npm i

compile:
	@truffle compile

deploy:
	@docker-compose up -d
	@truffle deploy

deploy-testnet:
	@truffle deploy --verbose-rpc --reset --network ropsten

verify-testnet:
	@truffle run verify SafePayment --network ropsten

tests:
	@docker-compose up -d
	@truffle test