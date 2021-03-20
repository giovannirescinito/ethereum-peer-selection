var Utils = artifacts.require("Utils");
var Allocations = artifacts.require("Allocations");
var Proposals = artifacts.require("Proposals");

module.exports = function (deployer) {
  deployer.deploy(Utils, {overwrite: true});
  deployer.deploy(Allocations, {overwrite: true});
  deployer.deploy(Proposals, {overwrite: true});
};
