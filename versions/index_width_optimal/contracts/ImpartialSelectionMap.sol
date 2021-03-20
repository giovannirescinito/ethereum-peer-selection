// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "contracts/ImpartialSelection.sol";
import "contracts/ExactDollarPartitionMap.sol";


contract ImpartialSelectionMap is ImpartialSelection{
    Scores.ScoreMap private scoreMap;
    
    constructor(address tokenAddress) ImpartialSelection(tokenAddress) public{}

    function endRevealPhase() override public{
        super.endRevealPhase();
        ExactDollarPartitionMap.finalizeScoreMap(scoreMap,partition,Proposals.getOptimalWidth(proposals));
    }

    function revealEvaluations(uint tokenId, uint randomness, uint[] calldata evaluations) override public returns (uint[] memory){
        uint[] memory assignments = super.revealEvaluations(tokenId, randomness, evaluations);
        ExactDollarPartitionMap.addToScoreMap(scoreMap,Proposals.getIdFromToken(proposals,tokenId), assignments, evaluations);
        return evaluations;
    }

    function impartialSelection(uint k, uint randomness) override public{
        super.impartialSelection(k, randomness);
        ExactDollarPartitionMap.exactDollarPartition(partition, scoreMap, allocations, randomness, k, Proposals.getOptimalWidth(proposals));
    }
}