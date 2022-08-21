const Payments = artifacts.require("SafePayment");

const { toBN } = web3.utils;

const {
    BN,           // Big Number support
    constants,    // Common constants, like the zero address and largest integers
    expectEvent,  // Assertions for emitted events
    expectRevert, // Assertions for transactions that should fail
  } = require('@openzeppelin/test-helpers');

const toWei = (ammount, unit="ether") => {
    return web3.utils.toWei("" + ammount, unit);
}

const accountsWithBalance = async (accounts) => {
    accsWithBalance = []
    for (let acc of accounts) {
        accWithBalance = {
            address: acc,
            startBalance: await web3.eth.getBalance(acc)
        }
        accsWithBalance.push(accWithBalance)
    }
    return accsWithBalance
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
            accWithBalance = await accountsWithBalance(accounts)

            from = accWithBalance[0]
            to = accWithBalance[1]
            validator = accWithBalance[2]

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
            const p = await payments.payments(new BN(1));
            assert.equal(p.isValidated || p.isApproved || p.isPaid, false);
            assert.equal(p.paymentValue.toString(), toBN(toWei(1)).toString());
            assert.equal(p.validationFee.toString(), toBN(toWei(0.01)).toString());
            assert.equal(p.receiver, to.address);
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

    describe("approveEvent", async () => {
        var approveResponse
        let from, to, validator
        let validationFee
        before(async () => {
            accWithBalance = await accountsWithBalance(accounts)

            from = accWithBalance[0]
            to = accWithBalance[1]
            validator = accWithBalance[2]

            ammount = toBN(toWei(1, "ether"));
            validationFee = toBN(toWei(0.01, "ether"));

            // Create payment for test
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
                eventID: new BN(3),
                issuer: from.address,
                parties: [to.address],
                validators: [validator.address],
            });

            eventID = 3; // Sets event id after assert
        })

        it("should'nt let anyone an non-existante payment", async() => {
            await expectRevert(payments.approveEvent(100000, toBN(0), {
                from: from.address,
            }), "payment id doesn't exist");
        });

        it("should'nt let owner validate the transaction", async() => {
            await expectRevert(payments.approveEvent(eventID, toBN(0), {
                from: from.address,
            }), "msg.sender is not a valid validator for the payment");
        });

        it("should'nt let receiver validate the transaction", async() => {
            await expectRevert(payments.approveEvent(eventID, toBN(0), {
                from: to.address,
            }), "msg.sender is not a valid validator for the payment");
        });

        it("should'nt let non-validator validate the transaction", async() => {
            await expectRevert(payments.approveEvent(eventID, toBN(0), {
                from: accounts[5],
            }), "msg.sender is not a valid validator for the payment");
        });

        it("shouldn't have changed the isApproved and isFinal for the failed approval calls", async() => {
            resp = await payments.getEventStatus(eventID)
            assert.equal(false, resp.isApproved || resp.isFinal)
        });

        it("should let validator validate the transaction", async() => {
            approveResponse = await payments.approveEvent(eventID, toBN(0), {
                from: validator.address,
            });
        });

        it("should emit the EventApproved upon approval", async () => {
            expectEvent.inLogs(approveResponse.logs, "EventApproved", {
                eventID: new BN(eventID),
                validator: validator.address,
                approvalRate: new BN(0),
            });
        });

        it("should emit the EthTransfer event upon approval", async() => {
            expectEvent.inLogs(approveResponse.logs, "EthTransfer", {
                to: validator.address,
                ammount: validationFee
            });
        });

        it("should have transfered the validation fees to the validator", async() => {
            const startBalance = toBN(validator.startBalance);
            // Obtain gasPrice from the transaction
            const tx = await web3.eth.getTransaction(approveResponse.tx);
            const gasUsed = toBN(approveResponse.receipt.gasUsed);
            const gasPrice = toBN(tx.gasPrice);
            // Final balance
            const final = toBN(await web3.eth.getBalance(validator.address));

            assert.equal(final.toString(), startBalance.sub(gasPrice.mul(gasUsed)).add(validationFee).toString(), "Must be equal");
        });

        it("should have set isApproved and isFinal for the payment", async() => {
            resp = await payments.getEventStatus(eventID)
            assert.equal(true, resp.isApproved && resp.isFinal)
        });

        it("shouldn't let validator validate the transaction again", async() => {
            await expectRevert(payments.approveEvent(eventID, toBN(0), {
                from: validator.address,
            }), "payment was already validated");
        });
    });

    describe("rejectEvent", async () => {
        var revokeResponse
        let from, to, validator
        let validationFee
        before(async () => {
            accWithBalance = await accountsWithBalance(accounts)
    
            from = accWithBalance[0]
            to = accWithBalance[1]
            validator = accWithBalance[2]
    
            ammount = toBN(toWei(1, "ether"));
            validationFee = toBN(toWei(0.01, "ether"));
    
            // Create payment for test
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
                eventID: new BN(4),
                issuer: from.address,
                parties: [to.address],
                validators: [validator.address],
            });
    
            eventID = 4; // Sets event id after assert
        })
    
        it("should'nt let anyone an non-existante payment", async() => {
            await expectRevert(payments.rejectEvent(100000, toBN(0), {
                from: from.address,
            }), "payment id doesn't exist");
        });
    
        it("should'nt let owner validate the transaction", async() => {
            await expectRevert(payments.rejectEvent(eventID, toBN(0), {
                from: from.address,
            }), "msg.sender is not a valid validator for the payment");
        });
    
        it("should'nt let receiver validate the transaction", async() => {
            await expectRevert(payments.rejectEvent(eventID, toBN(0), {
                from: to.address,
            }), "msg.sender is not a valid validator for the payment");
        });
    
        it("should'nt let non-validator validate the transaction", async() => {
            await expectRevert(payments.rejectEvent(eventID, toBN(0), {
                from: accounts[5],
            }), "msg.sender is not a valid validator for the payment");
        });
    
        it("shouldn't have changed the isApproved and isFinal for the failed approval calls", async() => {
            resp = await payments.getEventStatus(eventID)
            assert.equal(false, resp.isRevoked || resp.isFinal)
        });
    
        it("should let validator validate the transaction", async() => {
            revokeResponse = await payments.rejectEvent(eventID, toBN(0), {
                from: validator.address,
            });
        });
    
        it("should emit the EventRejected upon approval", async () => {
            expectEvent.inLogs(revokeResponse.logs, "EventRejected", {
                eventID: new BN(eventID),
                validator: validator.address,
                rejectionRate: new BN(0),
            });
        });
    
        it("should emit the EthTransfer event upon approval", async() => {
            expectEvent.inLogs(revokeResponse.logs, "EthTransfer", {
                to: validator.address,
                ammount: validationFee
            });
        });
    
        it("should have transfered the validation fees to the validator", async() => {
            const startBalance = toBN(validator.startBalance);
            // Obtain gasPrice from the transaction
            const tx = await web3.eth.getTransaction(revokeResponse.tx);
            const gasUsed = toBN(revokeResponse.receipt.gasUsed);
            const gasPrice = toBN(tx.gasPrice);
            // Final balance
            const final = toBN(await web3.eth.getBalance(validator.address));
    
            assert.equal(final.toString(), startBalance.sub(gasPrice.mul(gasUsed)).add(validationFee).toString(), "Must be equal");
        });
    
        it("should have set isApproved and isFinal for the payment", async() => {
            resp = await payments.getEventStatus(eventID)
            assert.equal(false,  resp.isApproved)
            assert.equal(true,  resp.isFinal)
        });

        it("shouldn't let validator validate the transaction again", async() => {
            await expectRevert(payments.rejectEvent(eventID, toBN(0), {
                from: validator.address,
            }), "payment was already validated");
        });
    });

    describe("claimPayment", async () => {
        let from, to, validator
        let validationFee, ammount
        before(async () => {
            accWithBalance = await accountsWithBalance(accounts)
    
            from = accWithBalance[0]
            to = accWithBalance[1]
            validator = accWithBalance[2]
    
            ammount = toBN(toWei(1, "ether"));
            validationFee = toBN(toWei(0.01, "ether"));
    
            // Creates 3 payments for testing:
            for (let i = 5; i < 8; i++) {
                // Create payment for test
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
                    eventID: new BN(i),
                    issuer: from.address,
                    parties: [to.address],
                    validators: [validator.address],
                });
            }

            nonValidatedPaymentID = 5
            approvedPaymentID = 6
            rejectedPaymentID = 7

            await payments.rejectEvent(rejectedPaymentID, toBN(0), {
                from: validator.address,
            });

            await payments.approveEvent(approvedPaymentID, toBN(0), {
                from: validator.address,
            });
    
            eventID = 5; // Sets event id after assert
        })
    
        it("should'nt let anyone retrieve payment form a non-validated payment", async() => {
            await expectRevert(payments.claimPayment(nonValidatedPaymentID, {
                from: from.address,
            }), "payment wasn't validated");
        });

        it("shouldn't allow owner to receive refund from approved payment ", async() => {
            await expectRevert(payments.claimPayment(approvedPaymentID, {
                from: from.address,
            }), "msg.sender is not the receiver of the payment.");
        });

        it("shouldn't allow receiver to receive refund from rejected payment ", async() => {
            await expectRevert(payments.claimPayment(rejectedPaymentID, {
                from: to.address,
            }), "msg.sender is not the issuer of this payment.");
        });

        it("should allow receiver to receive from approved payment ", async() => {
            resp = await payments.claimPayment(approvedPaymentID, {
                from: to.address,
            })

            expectEvent.inLogs(resp.logs, "EthTransfer", {
                to: to.address,
                ammount: ammount
            });
        });

        it("should allow issuer to refund from rejected payment ", async() => {
            resp = await payments.claimPayment(rejectedPaymentID, {
                from: from.address,
            })

            expectEvent.inLogs(resp.logs, "EthTransfer", {
                to: from.address,
                ammount: ammount
            });
        });
    });

});