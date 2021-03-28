// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "contracts/ImpartialSelection.sol";
import "contracts/ExactDollarPartitionMatrix.sol";


contract ImpartialSelectionMatrix is ImpartialSelection{
    uint[][] private scoreMatrix;
    
    constructor(address tokenAddress) ImpartialSelection(tokenAddress) public{}

    function endCommitmentPhase() public override{
        super.endCommitmentPhase();
        scoreMatrix = ExactDollarPartitionMatrix.initializeScoreMatrix(Proposals.length(proposals));
    }

    function endRevealPhase() public override{
        super.endRevealPhase();
        ExactDollarPartitionMatrix.finalizeScoreMatrix(scoreMatrix,partition,scoreAccumulated);
    }

    function revealEvaluations(uint tokenId, uint randomness, uint[] calldata evaluations) public override returns (uint[] memory){
        uint id = Proposals.getIdFromToken(proposals,tokenId);
        require(scoreMatrix[id].length == 0, "Already revealed");
        uint[] memory assignments = super.revealEvaluations(tokenId,randomness,evaluations);
        ExactDollarPartitionMatrix.addToScoreMatrix(scoreMatrix,scoreAccumulated,id, assignments, evaluations);
        return evaluations;
    }

    function getScores() external view returns (uint[][] memory){
        return Zipper.reconstructScoreMatrix(scoreMatrix);
    }
}