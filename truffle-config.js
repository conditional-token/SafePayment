var HDWalletProvider = require("truffle-hdwallet-provider")

TESTNET_MNEMONIC_LOCAL = 'minimum symptom minute gloom tragic situate silver mechanic salad amused elite beef'

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // for more about customizing your Truffle configuration!
  compilers: {
    solc: {
      version: "pragma"
      }
    },
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*" // Match any network id
    },
    ropsten: {
      provider: function() {
        return new HDWalletProvider(TESTNET_MNEMONIC_LOCAL, "https://ropsten.infura.io/v3/" + process.env.ROPSTEN_API_KEY)
      },
      network_id: "*",
      networkCheckTimeout: 10000,
      gas: 4000000      //make sure this gas allocation isn't over 4M, which is the max
    },
  }
};
