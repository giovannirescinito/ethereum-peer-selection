// SPDX-License-Identifier: UNLICENSED


pragma solidity >=0.4.18;
pragma experimental ABIEncoderV2;

import "contracts/Zipper.sol";

library Scores{

    struct ScoreMap{
        mapping(uint=>uint[]) reviewsFrom;
        mapping(uint=>uint[]) reviewsTo;   
    }
    
    function checkSubmitted(ScoreMap storage map, uint reviewer) view external returns (bool){
        return (map.reviewsTo[reviewer].length != 0);
    }

    function setReviews(ScoreMap storage map, uint reviewer, uint[] memory reviewed, uint[] memory evaluations) external {
        uint[] memory peers;
        uint[] memory scores;
        map.reviewsTo[reviewer] = Zipper.zipDoubleArray(reviewed,evaluations);
        for(uint i=0;i<reviewed.length;i++){
            uint[] memory unzipped = Zipper.unzipDoubleArray(map.reviewsFrom[reviewed[i]]);
            (peers,scores) = extractPeersAndScores(unzipped,true);
            peers[peers.length-1] = reviewer;
            scores[scores.length-1] = evaluations[i];
            map.reviewsFrom[reviewed[i]] = Zipper.zipDoubleArray(peers,scores);
        }
    }

    function reviewsSubmitted(ScoreMap storage map, uint reviewer) view public returns (uint[] memory, uint[] memory) {
        return extractPeersAndScores(Zipper.unzipDoubleArray(map.reviewsTo[reviewer]),false);
    }

    function reviewsReceived(ScoreMap storage map, uint reviewed) view public returns (uint[] memory, uint[] memory) {
        return extractPeersAndScores(Zipper.unzipDoubleArray(map.reviewsFrom[reviewed]),false);
    }

    function extractPeersAndScores(uint[] memory array, bool set) pure private returns (uint[] memory, uint[] memory){
        uint[] memory peers;
        uint[] memory scores;
        if (set){
            peers = new uint[](array.length/2+1);
            scores = new uint[](array.length/2+1);
        }else{
            peers = new uint[](array.length/2);
            scores = new uint[](array.length/2);
        }
        uint i = 0;
        for (uint j=0;j<array.length;j+=2){
            peers[i] = array[j];
            scores[i++] = array[j+1];
        }
        return (peers,scores);
    }
}