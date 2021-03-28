// SPDX-License-Identifier: UNLICENSED


pragma solidity >=0.4.18;
pragma experimental ABIEncoderV2;


import "contracts/ExactDollarPartition.sol";

library ExactDollarPartitionNoStorage {

    function finalizeScores(mapping(uint=>bool) storage revealed, uint[][] storage partition, mapping(uint=>uint) storage scoreAccumulated) external{
        uint[][] memory part = Zipper.unzipMatrix(partition,8);
        uint n = 0;
        for (uint i=0;i<partition.length;i++){
            n += part[i].length;
        }
        uint smallerSize = n % part.length;
        uint[] memory accumulator = new uint[](n);
        uint value = Utils.C/(n-part[0].length);
        for (uint i=0;i<part.length;i++){
            if (i == smallerSize){
                value = Utils.C/(n-part[i].length);
            }
            for (uint j=0;j<part[i].length;j++){
                uint id = part[i][j];
                if (!revealed[id]){
                    for (uint k=0;k<part.length;k++){
                        if (i!=k){
                            for (uint x=0;x<part[k].length;x++){
                                accumulator[part[k][x]] += value;
                            }
                        }
                    }
                }
            }
        }
        for (uint k=0;k<n;k++){
            if (accumulator[k]!=0){
                scoreAccumulated[k] += accumulator[k];
            }
        }
    }
    
    function addScores(mapping(uint=>bool) storage revealed, mapping(uint=>uint) storage scoreAccumulated, uint index, uint[] calldata assignments, uint[] memory evaluations) external{
        uint sum = 0;
        for (uint j=0;j<assignments.length;j++){
            sum += evaluations[j];
        }
        if (sum != 0){
            for (uint j=0;j<assignments.length;j++){
                evaluations[j] = evaluations[j]*Utils.C/sum;
                scoreAccumulated[assignments[j]] += evaluations[j];
            }
            revealed[index] = true;
        }
    }
}