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
        ExactDollarPartitionMatrix.finalizeScoreMatrix(scoreMatrix,partition);
    }
    function revealEvaluations(uint tokenId, uint randomness, uint[] calldata evaluations) public override returns (uint[] memory){
        uint[] memory assignments = super.revealEvaluations(tokenId,randomness,evaluations);
        ExactDollarPartitionMatrix.addToScoreMatrix(scoreMatrix,Proposals.getIdFromToken(proposals,tokenId), assignments, evaluations);
        return evaluations;
    }

    function calculateQuotas(uint k) public override{
        super.calculateQuotas(k);
        quotas = ExactDollarPartitionMatrix.calculateQuotas(partition,scoreMatrix,k);
    }

    function selectWinners() public override{
        super.selectWinners();
        Utils.Element[] memory winners = ExactDollarPartitionMatrix.selectWinners(partition, scoreMatrix, selectedAllocation);
        emit ExactDollarPartition.Winners(winners);
    }
    
    function getScoreMatrix() external view returns (uint[][] memory){
        return Zipper.reconstructScoreMatrix(scoreMatrix);
    }
}