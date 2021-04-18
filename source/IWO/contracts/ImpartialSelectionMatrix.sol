// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "contracts/ImpartialSelection.sol";
import "contracts/ExactDollarPartitionMatrix.sol";

/// @title Impartial Selection Matrix implementation
/// @author Giovanni Rescinito
/// @notice smart contract implementing the system proposed, using a matrix as support data structure for scores
contract ImpartialSelectionMatrix is ImpartialSelection{
    // scores data structure implemented as a matrix where each row contains the reviews submitted by each agent,
    // while each column contains the reviews received by each agent
    uint[][] private scoreMatrix;

    /// @notice creates a new instance of the contract
    /// @param tokenAddress address of the PET token to connect to the contract
    constructor(address tokenAddress) ImpartialSelection(tokenAddress) public{}

    /// @notice ends the commitment phase and initializes the score matrix
    function endCommitmentPhase() public override{
        super.endCommitmentPhase();
        scoreMatrix = ExactDollarPartitionMatrix.initializeScoreMatrix(Proposals.length(proposals));
    }

    /// @notice ends the reveal phase and checks that everyone submitted their scores
    function endRevealPhase() public override{
        super.endRevealPhase();
        ExactDollarPartitionMatrix.finalizeScoreMatrix(scoreMatrix,partition);
    }

    /// @notice performs the reveal operation and updates the scores
    /// @param tokenId token used during the commitment phase, to retrieve the corresponding commitment
    /// @param randomness randomness used to generate the commitment
    /// @param evaluations scores used to generate the commitment
    /// @return the evaluations provided
    function revealEvaluations(uint tokenId, uint randomness, uint[] calldata evaluations) public override returns (uint[] memory){
        uint[] memory assignments = super.revealEvaluations(tokenId,randomness,evaluations);
        ExactDollarPartitionMatrix.addToScoreMatrix(scoreMatrix,Proposals.getIdFromToken(proposals,tokenId), assignments, evaluations);
        return evaluations;
    }

    /// @notice executes the actual selection by invoking Exact Dollar Partition
    /// @param k the number of winners to select
    /// @param randomness the randomness used to select the allocation of winners per cluster to use
    function impartialSelection(uint k, uint randomness) public override{
        super.impartialSelection(k, randomness);        
        ExactDollarPartitionMatrix.exactDollarPartition(partition, scoreMatrix, allocations, randomness, k);
    }

    /// @notice returns a representation of the scores provided
    /// @return the scores matrix
    function getScores() override external view returns (uint[][] memory){
        return Zipper.reconstructScoreMatrix(scoreMatrix);
    }
}