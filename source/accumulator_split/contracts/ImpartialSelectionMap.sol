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
        ExactDollarPartitionMap.finalizeScoreMap(scoreMap,partition,scoreAccumulated);
    }

    function revealEvaluations(uint tokenId, uint randomness, uint[] calldata evaluations) override public returns (uint[] memory){
        uint id = Proposals.getIdFromToken(proposals,tokenId);
        require(!Scores.checkSubmitted(scoreMap,id), "Already revealed");
        uint[] memory assignments = super.revealEvaluations(tokenId, randomness, evaluations);
        ExactDollarPartitionMap.addToScoreMap(scoreMap,scoreAccumulated,Proposals.getIdFromToken(proposals,tokenId), assignments, evaluations);
        return evaluations;
    }

    function getScores() view external returns(uint[][] memory){
        uint n = Proposals.length(proposals);
        uint[][] memory map= new uint[][](n);
        uint[] memory peers;
        uint[] memory scores;
        for (uint i=0;i<n;i++){
            (peers,scores) = Scores.reviewsSubmitted(scoreMap,i);
            map[i] = new uint[](n);
            for (uint j=0;j<peers.length;j++){
                map[i][peers[j]] = scores[j];
            }
        }
        return map;
    }
}