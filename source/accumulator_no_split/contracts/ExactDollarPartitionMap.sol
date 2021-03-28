// SPDX-License-Identifier: UNLICENSED


pragma solidity >=0.4.18;
pragma experimental ABIEncoderV2;


import "contracts/ExactDollarPartition.sol";
import "contracts/Scores.sol";

library ExactDollarPartitionMap {

    function finalizeScoreMap(Scores.ScoreMap storage scoreMap, uint[][] storage partition,mapping(uint=>uint) storage scoreAccumulated) external{
        uint[][] memory part = Zipper.unzipMatrix(partition,8);
        uint n = 0;
        for (uint i=0;i<partition.length;i++){
            n += part[i].length;
        }
        uint[] memory row = new uint[](0);
        bool modified;
        uint[] memory eval;
        uint[] memory assign;
        uint[] memory accumulator = new uint[](n);
        uint value;
        for (uint i=0;i<part.length;i++){
            modified = false;
            if (i == n % part.length){
                row = new uint[](0);
            }
            for (uint j=0;j<part[i].length;j++){
                uint id = part[i][j];
                // (peers,) = Scores.reviewsSubmitted(scoreMap, id);
                if (!Scores.checkSubmitted(scoreMap,id)){
                    if (!modified){
                        if (row.length == 0){
                            value = Utils.C/(n-part[i].length);
                            row = new uint[](n);
                            for (uint k=0;k<n;k++){
                                row[k] = value;
                            }
                        }
                        eval = new uint[](n-part[i].length);
                        assign = new uint[](n-part[i].length);
                        for (uint k=0;k<part[i].length;k++){
                            row[part[i][k]] = 0;
                        }
                        uint idx = 0;
                        for (uint k=0;k<row.length;k++){
                            if (row[k] != 0){
                                assign[idx] = k;
                                eval[idx++] = value;
                            }
                        }    
                        modified = true;
                    }
                    for (uint k=0;k<n;k++){
                        if (row[k]!=0){
                            accumulator[k] += value;
                        }
                    }
                    Scores.setReviews(scoreMap,id,assign,eval);
                }
            }
            if (modified){
                for (uint k=0;k<part[i].length;k++){
                    row[part[i][k]] = value;
                }
            }
        }
        for (uint k=0;k<n;k++){
            if (accumulator[k]!=0){
                scoreAccumulated[k] += accumulator[k];
            }
        }
    }

    function addToScoreMap(Scores.ScoreMap storage scoreMap, mapping(uint=>uint) storage scoreAccumulated, uint index, uint[] calldata assignments, uint[] memory evaluations) external{
        uint sum = 0;
        for (uint j=0;j<assignments.length;j++){
            sum += evaluations[j];
        }
        if (sum != 0){
            for (uint j=0;j<assignments.length;j++){
                evaluations[j] = evaluations[j]*Utils.C/sum;
                scoreAccumulated[assignments[j]] += evaluations[j];
            }
            Scores.setReviews(scoreMap, index, assignments, evaluations);
        }
    }
}
