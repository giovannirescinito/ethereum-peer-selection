// SPDX-License-Identifier: UNLICENSED


pragma solidity >=0.4.18;
pragma experimental ABIEncoderV2;


import "contracts/ExactDollarPartition.sol";

library ExactDollarPartitionMatrix {

    function initializeScoreMatrix(uint n) pure external returns (uint[][] memory){
        return new uint[][](n);
    }

    function finalizeScoreMatrix(uint[][] storage scoreMatrix, uint[][] storage partition, mapping(uint=>uint) storage scoreAccumulated) external{
        uint n = scoreMatrix.length;
        uint[][] memory part = Zipper.unzipMatrix(partition,16);
        uint smallerSize = n % part.length;
        uint[] memory row = new uint[](0);
        bool modified;
        uint[] memory array;
        uint[] memory accumulator = new uint[](n);
        uint value;
        uint c = Utils.C;
        for (uint i=0;i<part.length;i++){
            modified = false;
            if (i == smallerSize){
                row = new uint[](0);
            }
            for (uint j=0;j<part[i].length;j++){
                uint id = part[i][j];
                if (scoreMatrix[id].length == 0){
                    if (!modified){
                        if (row.length == 0){
                            value = c/(n-part[i].length);
                            row = new uint[](n);
                            for (uint k=0;k<n;k++){
                                row[k] = value;
                            }
                        }
                        array = new uint[](2*(n-part[i].length));
                        for (uint k=0;k<part[i].length;k++){
                            row[part[i][k]] = 0;
                        }
                        uint idx = 0;
                        for (uint k=0;k<row.length;k++){
                            if (row[k] != 0){
                                array[idx++] = k;
                                array[idx++] = value;
                            }
                        }    
                        modified = true;
                    }
                    for (uint k=0;k<n;k++){
                        if (row[k]!=0){
                            accumulator[k] += value;
                        }
                    }
                    scoreMatrix[id] = Zipper.zipArray(array, 16);
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
    
    function addToScoreMatrix(uint[][] storage scoreMatrix, mapping(uint=>uint) storage scoreAccumulated, uint index, uint[] calldata assignments, uint[] memory evaluations) external{
        uint sum = 0;
        uint c = Utils.C;
        for (uint j=0;j<assignments.length;j++){
            sum += evaluations[j];
        }
        uint[] memory array = new uint[](2*assignments.length);
        if (sum != 0){
            uint idx = 0;
            for (uint j=0;j<assignments.length;j++){
                array[idx++] = assignments[j];
                evaluations[j] = evaluations[j]*c/sum;
                array[idx++] = evaluations[j];
                scoreAccumulated[assignments[j]] += evaluations[j];
            }
            scoreMatrix[index] = Zipper.zipArray(array,16);
        }
    }
}
