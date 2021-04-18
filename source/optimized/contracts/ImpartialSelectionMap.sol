// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "contracts/ImpartialSelection.sol";
import "contracts/ExactDollarPartitionMap.sol";

/// @title Impartial Selection Map implementation
/// @author Giovanni Rescinito
/// @notice smart contract implementing the system proposed, using a map as support data structure for scores
contract ImpartialSelectionMap is ImpartialSelection{
    Scores.ScoreMap private scoreMap;   // scores data structure implemented as a double map
    
    /// @notice creates a new instance of the contract
    /// @param tokenAddress address of the PET token to connect to the contract
    constructor(address tokenAddress) ImpartialSelection(tokenAddress) public{}

    /// @notice ends the reveal phase and checks that everyone submitted their scores
    function endRevealPhase() override public{
        super.endRevealPhase();
        ExactDollarPartitionMap.finalizeScoreMap(scoreMap,partition);
    }

    /// @notice performs the reveal operation and updates the scores
    /// @param tokenId token used during the commitment phase, to retrieve the corresponding commitment
    /// @param randomness randomness used to generate the commitment
    /// @param evaluations scores used to generate the commitment
    /// @return the evaluations provided
    function revealEvaluations(uint tokenId, uint randomness, uint[] calldata evaluations) override public returns (uint[] memory){
        uint[] memory assignments = super.revealEvaluations(tokenId, randomness, evaluations);
        ExactDollarPartitionMap.addToScoreMap(scoreMap,Proposals.getIdFromToken(proposals,tokenId), assignments, evaluations);
        return evaluations;
    }

    /// @notice executes the actual selection of the winners
    /// @param k number of winners to select
    /// @param randomness random value used to draw an allocation from the possible ones
    function impartialSelection(uint k, uint randomness) override public{
        super.impartialSelection(k, randomness);
        ExactDollarPartitionMap.exactDollarPartition(partition, scoreMap, allocations, randomness, k);
    }

    /// @notice returns a representation of the scores provided
    /// @return the scores submitted by users organized in a matrix where each row contains the reviews submitted by a user,
    ///         while each column contains the reviews received by a user
    function getScores() view override external returns(uint[][] memory){
        uint n = Proposals.length(proposals);
        uint[][] memory map= new uint[][](n);
        for (uint i=0;i<n;i++){
            Scores.Evaluation[] memory scores = Scores.reviewsSubmitted(scoreMap,i);
            map[i] = new uint[](n);
            for (uint j=0;j<scores.length;j++){
                map[i][scores[j].peer] = scores[j].score;
            }
        }
        return map;
    }
}