var HDWalletProvider = require("truffle-hdwallet-provider")

TESTNET_MNEMONIC_LOCAL = 'crouch clever swing decide woman glide picnic ostrich fatigue depart despair success'//'minimum symptom minute gloom tragic situate silver mechanic salad amused elite beef'

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // for more about customizing your Truffle configuration!
  compilers: {
    solc: {
      version: "pragma"
      }
    },
  plugins: ['truffle-plugin-verify'],
  api_keys: {
    etherscan: "6XQ2RV4KFJMIQJBNQ22BUIC3H1SUTK5Z9N"//"CIHQZ97VBFXRR1Z1Q2HUMNSHM9HDA28QUW"
  },
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*" // Match any network id
    },
    sepolia: {
      pollingInterval: 30000,
      networkCheckTimeout: 100000,
      provider: function() {
        return new HDWalletProvider(TESTNET_MNEMONIC_LOCAL, "https://sepolia.infura.io/v3/392267faef4f427ebba0b50d231385e4" )
      },
      network_id: "11155111",//"*"
      gas: 4465030      //make sure this gas allocation isn't over 4M, which is the max
    },
  }
};
