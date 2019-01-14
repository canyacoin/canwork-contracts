var CanWorkAdmin = artifacts.require("../contracts/CanWorkAdmin.sol");

module.exports = function(deployer) {
  deployer.deploy(CanWorkAdmin);
}