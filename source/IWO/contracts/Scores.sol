// SPDX-License-Identifier: MIT

pragma solidity >=0.4.18;
pragma experimental ABIEncoderV2;


/// @title Map-based scores definition
/// @author Giovanni Rescinito
/// @notice proposals submitted by agents, along with the corresponding assignment and commitment
library Scores{

    // Data Structures

    /// @notice Evaluation aggregated data structure
    struct Evaluation {
        uint128 peer;       // the index of the peer agent
        uint128 score;      // the score provided
    }

    /// @notice Dictionary containing reviews
    struct ReviewsMap {
        Evaluation[] evaluations;           // list of evaluations
        mapping (uint => uint) indexes;     // maps the agent to the corresponding evaluation in the list
    }

    /// @notice Double map data structure for storing scores
    struct ScoreMap{
        mapping(uint=>ReviewsMap) reviewsFrom;      // Collects the reviews received by each agent
        mapping(uint=>ReviewsMap) reviewsTo;        // Collects the reviews submitted by each agent
    }
    
    /// @notice sets the score exchanged between two agents
    /// @param map scores data structure related to a specific agent
    /// @param peer index of the peer agent
    /// @param evaluation score proposed
    function set (ReviewsMap storage map, uint peer, uint evaluation) private {
        uint keyIndex = map.indexes[peer];
        if (keyIndex == 0) { 
            map.evaluations.push(Evaluation(uint128(peer),uint128(evaluation)));
            map.indexes[peer] = map.evaluations.length;
        } else {
            map.evaluations[keyIndex - 1].score = uint128(evaluation);
        }
    }

    /// @notice stores the review submitted by an agent in the scores data structure
    /// @param map scores data structure
    /// @param reviewer index of the reviewer in the proposals set
    /// @param reviewed index of the reviewed agent
    /// @param evaluation score submitted by the reviewer
    function setReview(ScoreMap storage map, uint reviewer, uint reviewed, uint evaluation) external {
        set(map.reviewsTo[reviewer], reviewed, evaluation);
        set(map.reviewsFrom[reviewed], reviewer, evaluation);
    }

    /// @notice returns the reviews submitted by the agent specified
    /// @param map scores data structure
    /// @param reviewer index of the reviewer in the proposals set
    /// @return the list of the evaluations provided, containing scores and peers
    function reviewsSubmitted(ScoreMap storage map, uint reviewer) view public returns (Evaluation[] memory) {
        return map.reviewsTo[reviewer].evaluations;
    }

    /// @notice returns the reviews received by the agent specified
    /// @param map scores data structure
    /// @param reviewed index of the agent in the proposals set
    /// @return the list of the evaluations received, containing scores and peers
    function reviewsReceived(ScoreMap storage map, uint reviewed) view public returns (Evaluation[] memory) {
        return map.reviewsFrom[reviewed].evaluations;
    }
}
