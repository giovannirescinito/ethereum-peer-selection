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
        uint[][] memory part = Zipper.unzipMatrix(partition,Zipper.optimalWidth(scoreMatrix.length));
        uint[] memory row = new uint[](0);
        bool modified;
        uint[] memory array;
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
                        array = new uint[](2*(n-part[i].length));
                        uint value = Utils.C/(n-part[i].length);
                        for (uint k=0;k<part[i].length;k++){
                            tmp[part[i][k]] = 0;
                        }
                        uint idx = 0;
                        for (uint k=0;k<tmp.length;k++){
                            if (tmp[k] != 0){
                                array[idx++] = k;
                                array[idx++] = value;
                            }
                        }    
                        modified = true;
                    }
                    scoreMatrix[id] = Zipper.zipArray(array, 32);
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
    function addToScoreMatrix(uint[][] storage scoreMatrix, uint index, uint[] calldata assignments, uint[] calldata evaluations) external{
        uint sum = 0;
        for (uint j=0;j<assignments.length;j++){
            sum += evaluations[j];
        }
        uint[] memory array = new uint[](2*assignments.length);
        if (sum != 0){
            uint idx = 0;
            for (uint j=0;j<assignments.length;j++){
                array[idx++] = assignments[j];
                array[idx++] = evaluations[j]*Utils.C/sum;
            }
            scoreMatrix[index] = Zipper.zipArray(array, 32);
        }
    }

    /// @notice executes the Exact Dollar Partition algorithm
    /// @param partition zipped matrix of the clusters in which proposals are divided
    /// @param scoreMatrix data structure containing the scores
    /// @param allocations dictionary containing the possible allocations found
    /// @param allocationRandomness random value used to draw an allocation from the possible ones
    /// @param k number of winners to select
    function exactDollarPartition(uint[][] storage partition, 
                                    uint[][] storage scoreMatrix, 
                                    Allocations.Map storage allocations,
                                    uint allocationRandomness,
                                    uint k) external {
        
        uint[][] memory part = Zipper.unzipMatrix(partition,Zipper.optimalWidth(scoreMatrix.length));
        uint[][] memory scoreMat = Zipper.reconstructScoreMatrix(scoreMatrix);
        uint[] memory quotas = calculateQuotas(part, scoreMat, k);
        emit ExactDollarPartition.QuotasCalculated(quotas);
        ExactDollarPartition.randomizedAllocationFromQuotas(allocations, quotas);
        uint[] memory selectedAllocation = ExactDollarPartition.selectAllocation(allocations, allocationRandomness);
        emit ExactDollarPartition.AllocationSelected(selectedAllocation);
        Utils.Element[] memory winners = selectWinners(part, scoreMat, selectedAllocation);
        emit ExactDollarPartition.Winners(winners);
    }

    /// @notice calculates quotas for each cluster starting from scores received by users
    /// @param partition matrix of the clusters in which proposals are divided
    /// @param scoreMatrix data structure containing the scores
    /// @param k number of winners to select
    /// @return quotas calculated
    function calculateQuotas(uint[][] memory partition, uint[][] memory scoreMatrix, uint k) pure private returns (uint[] memory){
        uint l = partition.length;
        uint n = uint(scoreMatrix[0].length);
        uint[] memory quotas = new uint[](l);
        for (uint i=0; i<l; i++) {
            quotas[i] = 0;
            for (uint j=0; j<l; j++) {
                if (i != j){
                    for (uint x=0; x<partition[i].length; x++){
                        for (uint y=0; y<partition[j].length; y++){
                            quotas[i] += scoreMatrix[(partition[j][y])][(partition[i][x])];
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
    function selectWinners(uint[][] memory partition, uint[][] memory scoreMatrix, uint[] memory allocation) pure private returns (Utils.Element[] memory){
        uint num = 0;
        for (uint i=0;i<allocation.length;i++){
            num+=allocation[i];
        }
        Utils.Element[] memory scoresSorted;
        Utils.Element[] memory winners = new Utils.Element[](num);
        uint[] memory scores;
        uint index;
        uint x = 0;
        for (uint i=0; i<partition.length; i++) {
            scores = new uint[](partition[i].length);
            for (uint j=0; j<partition[i].length; j++) {
                for (uint k=0; k<scoreMatrix.length; k++) {
                    scores[j] += scoreMatrix[k][partition[i][j]];
                }
            }
            scoresSorted = Utils.sort(scores);
            index = partition[i].length - 1;
            for (uint q=0; q<allocation[i]; q++) {
                Utils.Element memory e = scoresSorted[index--];
                winners[x++] = (Utils.Element(uint128(partition[i][e.id]), uint128(e.value)));
            }
        }
        return winners;
    }
}
