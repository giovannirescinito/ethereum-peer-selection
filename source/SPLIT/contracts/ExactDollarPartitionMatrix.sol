// SPDX-License-Identifier: MIT

pragma solidity >=0.4.18;
pragma experimental ABIEncoderV2;


import "contracts/ExactDollarPartition.sol";

/// @title Exact Dollar Partition matrix implementation
/// @author Giovanni Rescinito
/// @notice implements the matrix specific functions related to Exact Dollar Partition
library ExactDollarPartitionMatrix {

    /// @notice initializes the scores data structure
    /// @param n numbers of proposals submitted
    /// @return a nxn empty matrix to store scores
    function initializeScoreMatrix(uint n) pure external returns (uint[][] memory){
        return new uint[][](n);
    }

    /// @notice checks if all users revealed their evaluations, otherwise sets them according to Exact Dollar Partition
    /// @param scoreMatrix data structure containing the scores
    /// @param partition zipped matrix of the clusters in which proposals are divided
    function finalizeScoreMatrix(uint[][] storage scoreMatrix, uint[][] storage partition) external{
        uint n = scoreMatrix.length;
        uint[][] memory part = Zipper.unzipMatrix(partition,8);
        uint[] memory row = new uint[](0);
        bool modified;
        uint[] memory eval;
        uint[] memory assign;
        uint[] memory tmp;
        for (uint i=0;i<part.length;i++){
            modified = false;
            for (uint j=0;j<part[i].length;j++){
                uint id = part[i][j];
                if (scoreMatrix[id].length == 0){
                    if (!modified){
                        if (row.length == 0){
                            row = new uint[](n);
                            for (uint k=0;k<n;k++){
                                row[k] = 1;
                            }
                        }
                        tmp = row;
                        eval = new uint[](n-part[i].length);
                        assign = new uint[](n-part[i].length);
                        uint value = Utils.C/(n-part[i].length);
                        for (uint k=0;k<part[i].length;k++){
                            tmp[part[i][k]] = 0;
                        }
                        uint idx = 0;
                        for (uint k=0;k<tmp.length;k++){
                            if (tmp[k] != 0){
                                assign[idx] = k;
                                eval[idx++] = value;
                            }
                        }    
                        modified = true;
                    }
                    scoreMatrix[id] = Zipper.zipDoubleArray(assign, eval);
                }
            }
            if (modified){
                for (uint k=0;k<part[i].length;k++){
                    row[part[i][k]] = 1;
                }
            }
        }
    }
    
    /// @notice normalizes the scores received by a user when revealing and adds them to the corresponding data structure
    /// @param scoreMatrix data structure containing the scores
    /// @param index index of the agent who submitted the reviews
    /// @param assignments list of the works reviewed
    /// @param evaluations scores provided
    function addToScoreMatrix(uint[][] storage scoreMatrix, uint index, uint[] calldata assignments, uint[] memory evaluations) external{
        uint sum = 0;
        for (uint j=0;j<assignments.length;j++){
            sum += evaluations[j];
        }
        if (sum != 0){
            for (uint j=0;j<assignments.length;j++){
                evaluations[j] = evaluations[j]*Utils.C/sum;
            }
            scoreMatrix[index] = Zipper.zipDoubleArray(assignments, evaluations);
        }
    }

    /// @notice calculates quotas for each cluster starting from scores received by users
    /// @param partition matrix of the clusters in which proposals are divided
    /// @param scoreMatrix data structure containing the scores
    /// @param k number of winners to select
    /// @return quotas calculated
    function calculateQuotas(uint[][] storage partition, uint[][] storage scoreMatrix, uint k) view external returns (uint[] memory){
        uint[][] memory part = Zipper.unzipMatrix(partition,8);
        uint[][] memory scoreMat = Zipper.reconstructScoreMatrix(scoreMatrix);
        uint l = partition.length;
        uint n = uint(scoreMat[0].length);
        uint[] memory quotas = new uint[](l);
        for (uint i=0; i<l; i++) {
            quotas[i] = 0;
            for (uint j=0; j<l; j++) {
                if (i != j){
                    for (uint x=0; x<part[i].length; x++){
                        for (uint y=0; y<part[j].length; y++){
                            quotas[i] += scoreMat[(part[j][y])][(part[i][x])];
                        }
                    }
                }
            }
            quotas[i] = quotas[i]*k/n;
        }
        return quotas;
    }
   
    /// @notice selects the winners from each cluster given the allocation selected
    /// @param partition matrix of the clusters in which proposals are divided
    /// @param scoreMatrix data structure containing the scores
    /// @param allocation number of winners to select from each cluster
    /// @return selection winners' id and score
    function selectWinners(uint[][] storage partition, uint[][] storage scoreMatrix, uint[] memory allocation) view external returns (Utils.Element[] memory){
        uint[][] memory part = Zipper.unzipMatrix(partition,8);
        uint[][] memory scoreMat = Zipper.reconstructScoreMatrix(scoreMatrix);
        uint num = 0;
        for (uint i=0;i<allocation.length;i++){
            num+=allocation[i];
        }
        Utils.Element[] memory scoresSorted;
        Utils.Element[] memory winners = new Utils.Element[](num);
        uint[] memory scores;
        uint index;
        uint x = 0;
        for (uint i=0; i<part.length; i++) {
            scores = new uint[](part[i].length);
            for (uint j=0; j<part[i].length; j++) {
                for (uint k=0; k<scoreMat.length; k++) {
                    scores[j] += scoreMat[k][part[i][j]];
                }
            }
            scoresSorted = Utils.sort(scores);
            index = part[i].length - 1;
            for (uint q=0; q<allocation[i]; q++) {
                Utils.Element memory e = scoresSorted[index--];
                winners[x++] = (Utils.Element(uint128(part[i][e.id]), uint128(e.value)));
            }
        }
        return winners;
    }
}
