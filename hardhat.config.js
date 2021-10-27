require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-solhint");


module.exports = {
  solidity: {
    compilers: [
        {
            version: "0.8.9"
        }
    ]
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      mining: {
        auto: false,
      }
    }
  }
};
