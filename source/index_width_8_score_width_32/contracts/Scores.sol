// SPDX-License-Identifier: UNLICENSED


pragma solidity >=0.4.18;
pragma experimental ABIEncoderV2;

import "contracts/Zipper.sol";

library Scores{

    struct ScoreMap{
        mapping(uint=>uint[]) reviewsFrom;
        mapping(uint=>uint[]) reviewsTo;   
    }

    function setReviews(ScoreMap storage map, uint reviewer, uint[] memory reviewed, uint[] memory evaluations) external {
        uint[] memory peers;
        uint[] memory scores;
        uint[] memory tmp = compactArrays(reviewed, evaluations);
        map.reviewsTo[reviewer] = Zipper.zipArray(tmp,32);
        for(uint i=0;i<reviewed.length;i++){
            uint[] memory unzipped = Zipper.unzipArray(map.reviewsFrom[reviewed[i]],32);
            (peers,scores) = extractPeersAndScores(unzipped,true);
            peers[peers.length-1] = reviewer;
            scores[scores.length-1] = evaluations[i];
            map.reviewsFrom[reviewed[i]] = Zipper.zipArray(compactArrays(peers,scores),32);
        }
    }

    function reviewsSubmitted(ScoreMap storage map, uint reviewer) view public returns (uint[] memory, uint[] memory) {
        return extractPeersAndScores(Zipper.unzipArray(map.reviewsTo[reviewer],32),false);
    }

    function reviewsReceived(ScoreMap storage map, uint reviewed) view public returns (uint[] memory, uint[] memory) {
        return extractPeersAndScores(Zipper.unzipArray(map.reviewsFrom[reviewed],32),false);
    }

    function compactArrays(uint[] memory a, uint[] memory b)pure private returns(uint[] memory){
        require(a.length == b.length, "Different array sizes");
        uint[] memory tmp = new uint[](a.length*2);
        uint i = 0;
        for (uint j=0;j<a.length;j++){
            tmp[i++] = a[j];
            tmp[i++] = b[j];
        }
        return tmp;
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
