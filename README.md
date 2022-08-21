# Safe Payment

Safe payment is a smart contract implementation of marketplaces secure payment, enabling any entity to be the third party that validates payments and resolves disputes.

## Features

- Issue safe payments choosing the receiver and validators;
- Payments can be refunded if rejected by the validator.
- Payments can be reedemed after validated.
- The validator is an address on ethereum, so it can be a person you trust, another contract or even a machine that interacts with the network.

## Dependencies

- Solidity - Contract and interfaces
- Ganache - Personal Ethereum Network
- Docker - To run ganache on containers
- Truffle - Test framework and deployment
- This package uses node v16+ and NPM v8+

To install dependencies, run `make setup`

## How to run the contract?

To run the contract it must be deployed on a network. You can use ganache to deploy the contract locally and interact with it on your network. The makefile deploy command will create an instance of the ganache on docker and deploy the contract to it using truffle. The output will have the address where the contract is deployed.

```
    make deploy
```

The deployment of truffle will execute files in the migrations dir, that uses the builded artifacts and truffle to execute the deploy in the local ganache network.

## How to execute tests?

Tests are written in javascript using truffle suite and ganache. Run `make tests` to execute the tests in your local environment. The test command will execute all thests in the `test/` folder.

## Development

Want to contribute? Great! Just open a PR justifying your changes and it will be reviewed.