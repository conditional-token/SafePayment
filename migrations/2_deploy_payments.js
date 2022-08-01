var Payments = artifacts.require("PaymentContract");

module.exports = function(deployer) {
  deployer.deploy(Payments);
};