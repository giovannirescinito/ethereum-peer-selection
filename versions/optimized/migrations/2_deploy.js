var Allocations = artifacts.require("Allocations");
var ExactDollarPartition = artifacts.require("ExactDollarPartition");
var ExactDollarPartitionMap = artifacts.require("ExactDollarPartitionMap");
var ExactDollarPartitionMatrix = artifacts.require("ExactDollarPartitionMatrix");
var Phases = artifacts.require("Phases");
var Proposals = artifacts.require("Proposals");
var Scores = artifacts.require("Scores");
var Utils = artifacts.require("Utils");

var Token = artifacts.require("Token");

module.exports = function (deployer) {
  deployer.deploy(Phases,{overwrite:true});
  deployer.deploy(Scores,{overwrite:true});
  deployer.deploy(Utils, {overwrite: true});
  
  deployer.deploy(Allocations, {overwrite: true});
  deployer.deploy(Proposals, {overwrite: true});
  
  deployer.link(Allocations, ExactDollarPartition);
  deployer.link(Proposals, ExactDollarPartition);
  deployer.link(Utils, ExactDollarPartition);
    
  deployer.deploy(ExactDollarPartition,{overwrite:true});

  deployer.link(ExactDollarPartition, ExactDollarPartitionMap);
  deployer.link(Scores, ExactDollarPartitionMap);
  deployer.link(Utils, ExactDollarPartitionMap);
  
  deployer.deploy(ExactDollarPartitionMap,{overwrite:true});

  deployer.link(ExactDollarPartition, ExactDollarPartitionMatrix);
  deployer.link(Utils, ExactDollarPartitionMatrix);
  
  deployer.deploy(ExactDollarPartitionMatrix,{overwrite:true});

  deployer.deploy(Token,"Proposals Evaluation Token", "PET", "evaluation");
};
