// SPDX-License-Identifier: UNLICENSED


pragma solidity >=0.4.18;
pragma experimental ABIEncoderV2;


import "contracts/ExactDollarPartition.sol";
import "contracts/Scores.sol";

library ExactDollarPartitionMap {

    function finalizeScoreMap(Scores.ScoreMap storage scoreMap, uint[][] storage partition) external{
        uint[][] memory part = Zipper.unzipMatrix(partition,8);
        uint l = partition.length;
        uint n = 0;
        for (uint i=0;i<l;i++){
            n += part[i].length;
        }
        for (uint i=0;i<l;i++){
            for (uint j=0;j<part[i].length;j++){
                uint id = part[i][j];
                Scores.Evaluation[] memory e = Scores.reviewsSubmitted(scoreMap, id);
                if (e.length == 0){
                    uint value = Utils.C/(n-part[i].length);
                    for (uint k=0;k<l;k++){
                        if (i!=k){
                            for (uint x=0;x<part[k].length;x++){
                                Scores.setReview(scoreMap, id, part[k][x], value);
                            }
                        }
                    }
                }
            }
        }
    }

    function addToScoreMap(Scores.ScoreMap storage scoreMap, uint index, uint[] calldata assignments, uint[] calldata evaluations) external{
        uint sum = 0;
        for (uint j=0;j<assignments.length;j++){
            sum += evaluations[j];
        }
        if (sum != 0){
            for (uint j=0;j<assignments.length;j++){
                Scores.setReview(scoreMap, index, assignments[j], evaluations[j]*Utils.C/sum);
            }
        }
    }

    function exactDollarPartition(uint[][] storage partition, 
                                    Scores.ScoreMap storage scoreMap, 
                                    Allocations.Map storage allocations,
                                    uint allocationRandomness,
                                    uint k) external {
        
        uint[][] memory part = Zipper.unzipMatrix(partition,8);
        uint[] memory quotas = calculateQuotas(part, scoreMap, k);
        emit ExactDollarPartition.QuotasCalculated(quotas);
        ExactDollarPartition.randomizedAllocationFromQuotas(allocations, quotas);
        uint[] memory selectedAllocation = ExactDollarPartition.selectAllocation(allocations, allocationRandomness);
        emit ExactDollarPartition.AllocationSelected(selectedAllocation);
        Utils.Element[] memory winners = selectWinners(part, scoreMap, selectedAllocation);
        emit ExactDollarPartition.Winners(winners);
    }
    
    function calculateQuotas(uint[][] memory partition, Scores.ScoreMap storage scoreMap, uint k) view private returns (uint[] memory){
        uint l = partition.length;
        uint n = 0;
        for (uint i=0;i<l;i++){
            n+=partition[i].length;
        }
        uint[] memory quotas = new uint[](l);
        for (uint i=0; i<l; i++) {
            quotas[i] = 0;
            for (uint j=0; j<partition[i].length; j++){
                Scores.Evaluation[] memory e = Scores.reviewsReceived(scoreMap, partition[i][j]);
                for (uint x = 0;x<e.length;x++){
                    quotas[i] += e[x].score;
                }
            }
            quotas[i] = quotas[i]*k/n;
        }
        return quotas;
    }

    function selectWinners(uint[][] memory partition, Scores.ScoreMap storage scoreMap, uint[] memory allocation) view private returns (Utils.Element[] memory){
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
                Scores.Evaluation[] memory evaluations = Scores.reviewsReceived(scoreMap, partition[i][j]);
                for (uint k=0; k<evaluations.length; k++) {
                    scores[j] += evaluations[k].score;
                }
            }
            scoresSorted = Utils.sort(scores);
            index = partition[i].length - 1;
            for (uint j=0; j<allocation[i]; j++) {
                Utils.Element memory e = scoresSorted[index--];
                winners[x++] = (Utils.Element(uint128(partition[i][e.id]), uint128(e.value)));
            }
        }
        return winners;
    }
}
