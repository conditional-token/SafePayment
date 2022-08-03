const Payments = artifacts.require("SafePayment");

const { toBN } = web3.utils;

const { BN, expectEvent } = require('@openzeppelin/test-helpers');

const toWei = (ammount, unit="ether") => {
    return web3.utils.toWei("" + ammount, unit);
}

contract("SafePayment", (accounts) => {
    before(async () => {
        payments = await Payments.deployed();
    });

    describe("Create payment", async () => {
        let createResponse
        let from, to, validator
        let ammount, validationFee
        before("Creating the payment", async () => {
            from = {
                address: accounts[0],
                startBalance: await web3.eth.getBalance(accounts[0])
            }
    
            to = {
                address: accounts[1],
                startBalance: await web3.eth.getBalance(accounts[1])
            }
    
            validator = {
                address: accounts[2],
                startBalance: await web3.eth.getBalance(accounts[2])
            }
            ammount = toBN(toWei(1, "ether"));
            validationFee = toBN(toWei(0.01, "ether"));
            
            createResponse = await payments.createPayment(
                ammount,
                validationFee,
                to.address,
                [validator.address],
                { 
                    from: from.address,
                    value: toBN(toWei(1.01, "ether"))
                }
            );
        });

        it("should have created the EventCreated event", async () => {
            expectEvent.inLogs(createResponse.logs, "EventCreated", {
                eventID: new BN(1),
                issuer: from.address,
                parties: [to.address],
                validators: [validator.address],
              });
        });

        it("should have removed payment + fees from sender account", async () => {
            const startBalance = from.startBalance;
            const valueTransfered = ammount.add(validationFee);
            

            // Obtain gasPrice from the transaction
            const tx = await web3.eth.getTransaction(createResponse.tx);
            const gasUsed = toBN(createResponse.receipt.gasUsed);
            const gasPrice = toBN(tx.gasPrice);
            // Final balance
            const final = toBN(await web3.eth.getBalance(from.address));

            assert.equal(final.add(gasPrice.mul(gasUsed)).add(valueTransfered).toString(), startBalance.toString(), "Must be equal");
        });

        it("should have created the payment", async () => {
            const p = await payments._payments(new BN(1));
            assert.equal(p.isValidated || p.isApproved || p.isPaid, false);
            assert.equal(p.paymentValue.toString(), toBN(toWei(1)).toString());
            assert.equal(p.validationFee.toString(), toBN(toWei(0.01)).toString());
            assert.equal(p.payableTo, to.address);
            assert.equal(p.issuer, from.address);
        });

        it("should increment the id for the next payment created", async () => {
            createResponse = await payments.createPayment(
                ammount,
                validationFee,
                to.address,
                [validator.address],
                { 
                    from: from.address,
                    value: toBN(toWei(1.01, "ether"))
                }
            );

            expectEvent.inLogs(createResponse.logs, "EventCreated", {
                eventID: new BN(2),
                issuer: from.address,
                parties: [to.address],
                validators: [validator.address],
              });
        });
  });
});