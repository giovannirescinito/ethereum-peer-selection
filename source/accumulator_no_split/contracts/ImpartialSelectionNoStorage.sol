// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "contracts/ImpartialSelection.sol";
import "contracts/ExactDollarPartitionNoStorage.sol";


contract ImpartialSelectionNoStorage is ImpartialSelection{
    mapping(uint=>bool) private revealed;
    
    constructor(address tokenAddress) ImpartialSelection(tokenAddress) public{}

    function endRevealPhase() public override{
        super.endRevealPhase();
        ExactDollarPartitionNoStorage.finalizeScores(revealed,partition,scoreAccumulated);
    }

    function revealEvaluations(uint tokenId, uint randomness, uint[] calldata evaluations) public override returns (uint[] memory){
        uint id = Proposals.getIdFromToken(proposals,tokenId);
        require(!revealed[id], "Already revealed");
        uint[] memory assignments = super.revealEvaluations(tokenId,randomness,evaluations);
        ExactDollarPartitionNoStorage.addScores(revealed,scoreAccumulated,id, assignments, evaluations);
        return evaluations;
    }
}