var Payments = artifacts.require("SafePayment");

module.exports = function(deployer) {
  deployer.deploy(Payments);
};