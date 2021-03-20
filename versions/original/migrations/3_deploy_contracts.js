var ImpartialSelection = artifacts.require("ImpartialSelection");
var Utils = artifacts.require("Utils");
var Allocations = artifacts.require("Allocations");
var Proposals = artifacts.require("Proposals");
var Token = artifacts.require("Token");

module.exports = async (deployer) => {
    // await deployer.link(Utils, ImpartialSelection);
    // await deployer.link(Allocations, ImpartialSelection);
    // await deployer.link(Proposals, ImpartialSelection);
    await deployer.deploy(Token,"Proposals Evaluation Token", "PET", "evaluation");
    // await deployer.deploy(ImpartialSelection, Token.address);
    // t = await Token.deployed();
    // await t.transferOwnership(ImpartialSelection.address);
}

// module.exports = function (deployer) {
//     deployer.link(Utils, ImpartialSelection);
//     deployer.link(Allocations, ImpartialSelection);
//     deployer.link(Proposals, ImpartialSelection);
//     deployer.deploy(Token,"Proposals Evaluation Token", "PET", "evaluation").then(function(){
//         return deployer.deploy(ImpartialSelection, Token.address);
            
//     });
//     Token.deployed().transferOwnership(ImpartialSelection.address);
//     //ImpartialSelection.deployed().setTokenAddress(Token.deployed().address);  
// };
