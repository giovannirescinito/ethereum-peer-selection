// SPDX-License-Identifier: UNLICENSED


pragma solidity >=0.4.18;
pragma experimental ABIEncoderV2;


import "contracts/ExactDollarPartition.sol";

library ExactDollarPartitionMatrix {

    function initializeScoreMatrix(uint n) pure external returns (uint[][] memory){
        return new uint[][](n);
    }

    function finalizeScoreMatrix(uint[][] storage scoreMatrix, uint[][] storage partition) external{
        uint n = scoreMatrix.length;
        uint[][] memory part = partition;
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
                            for (uint j=0;j<n;j++){
                                row[j] = 1;
                            }
                        }
                        tmp = row;
                        array = new uint[]((n-part[i].length));
                        uint value = Utils.C/(n-part[i].length);
                        for (uint k=0;k<part[i].length;k++){
                            tmp[part[i][k]] = 0;
                        }
                        for (uint k=0;k<tmp.length;k++){
                            if (tmp[k] != 0){
                                array[k] = value;
                            }else{
                                array[k] = 0;
                            }
                        }    
                        modified = true;
                    }
                    scoreMatrix[id] = array;
                }
            }
            if (modified){
                for (uint k=0;k<part[i].length;k++){
                    row[part[i][k]] = 1;
                }
            }
        }
    }
    
    function addToScoreMatrix(uint[][] storage scoreMatrix, uint index, uint[] calldata assignments, uint[] calldata evaluations) external{
        uint sum = 0;
        for (uint j=0;j<assignments.length;j++){
            sum += evaluations[j];
        }
        if (sum != 0){
            for (uint j=0;j<assignments.length;j++){
                scoreMatrix[index][assignments[j]] = evaluations[j]*Utils.C/sum;
            }
        }
    }

    function exactDollarPartition(uint[][] storage partition, 
                                    uint[][] storage scoreMatrix, 
                                    Allocations.Map storage allocations,
                                    uint allocationRandomness,
                                    uint k) external {
        
        uint[][] memory part = partition;
        uint[][] memory scoreMat = scoreMatrix;
        uint[] memory quotas = calculateQuotas(part, scoreMat, k);
        emit ExactDollarPartition.QuotasCalculated(quotas);
        ExactDollarPartition.randomizedAllocationFromQuotas(allocations, quotas);
        uint[] memory selectedAllocation = ExactDollarPartition.selectAllocation(allocations, allocationRandomness);
        emit ExactDollarPartition.AllocationSelected(selectedAllocation);
        Utils.Element[] memory winners = selectWinners(part, scoreMat, selectedAllocation);
        emit ExactDollarPartition.Winners(winners);
    }

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
                winners[x++] = (Utils.Element(partition[i][e.id], e.value));
            }
        }
        return winners;
    }
}
