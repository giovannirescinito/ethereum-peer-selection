// SPDX-License-Identifier: UNLICENSED


pragma solidity >=0.4.18;
pragma experimental ABIEncoderV2;


library Scores{

    struct Evaluation {
        uint peer;
        uint score;
    }

    struct ReviewsMap {
        Evaluation[] evaluations;
        mapping (uint => uint) indexes;
    }

    struct ScoreMap{
        mapping(uint=>ReviewsMap) reviewsFrom;
        mapping(uint=>ReviewsMap) reviewsTo;   
    }
    
    function set (ReviewsMap storage map, uint peer, uint evaluation) private {
        uint keyIndex = map.indexes[peer];
        if (keyIndex == 0) { 
            map.evaluations.push(Evaluation(peer,evaluation));
            map.indexes[peer] = map.evaluations.length;
        } else {
            map.evaluations[keyIndex - 1].score = uint128(evaluation);
        }
    }

    function setReview(ScoreMap storage map, uint reviewer, uint reviewed, uint evaluation) external {
        set(map.reviewsTo[reviewer], reviewed, evaluation);
        set(map.reviewsFrom[reviewed], reviewer, evaluation);
    }

    function reviewsSubmitted(ScoreMap storage map, uint reviewer) view public returns (Evaluation[] memory) {
        return map.reviewsTo[reviewer].evaluations;
    }

    function reviewsReceived(ScoreMap storage map, uint reviewed) view public returns (Evaluation[] memory) {
        return map.reviewsFrom[reviewed].evaluations;
    }

    function getScore(ScoreMap storage map, uint reviewer, uint reviewed) view external returns (uint){
        uint keyIndex = map.reviewsTo[reviewer].indexes[reviewed];
        require (keyIndex != 0, "Review not present");
        return map.reviewsTo[reviewer].evaluations[keyIndex - 1].score;
    }
}
