// SPDX-License-Identifier: MIT

pragma solidity >=0.4.18;
pragma experimental ABIEncoderV2;


import "contracts/ExactDollarPartition.sol";
import "contracts/Scores.sol";

/// @title Exact Dollar Partition map implementation
/// @author Giovanni Rescinito
/// @notice implements the map specific functions related to Exact Dollar Partition
library ExactDollarPartitionMap {

    /// @notice checks if all users revealed their evaluations, otherwise sets them according to Exact Dollar Partition
    /// @param scoreMap data structure containing the scores
    /// @param partition matrix of the clusters in which proposals are divided
    function finalizeScoreMap(Scores.ScoreMap storage scoreMap, uint[][] storage partition) external{
        uint[][] memory part = partition;
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

    /// @notice normalize the scores received by a user when revealing and adds them to the corresponding data structure
    /// @param scoreMap data structure containing the scores
    /// @param index index of the agent who submitted the reviews
    /// @param assignments list of the works reviewed
    /// @param evaluations scores provided
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

    /// @notice executes the Exact Dollar Partition algorithm
    /// @param partition zipped matrix of the clusters in which proposals are divided
    /// @param scoreMap data structure containing the scores
    /// @param allocations dictionary containing the possible allocations found
    /// @param allocationRandomness random value used to draw an allocation from the possible ones
    /// @param k number of winners to select
    function exactDollarPartition(uint[][] storage partition, 
                                    Scores.ScoreMap storage scoreMap, 
                                    Allocations.Map storage allocations,
                                    uint allocationRandomness,
                                    uint k) external {
        
        uint[][] memory part = partition;
        uint[] memory quotas = calculateQuotas(part, scoreMap, k);
        emit ExactDollarPartition.QuotasCalculated(quotas);
        ExactDollarPartition.randomizedAllocationFromQuotas(allocations, quotas);
        uint[] memory selectedAllocation = ExactDollarPartition.selectAllocation(allocations, allocationRandomness);
        emit ExactDollarPartition.AllocationSelected(selectedAllocation);
        Utils.Element[] memory winners = selectWinners(part, scoreMap, selectedAllocation);
        emit ExactDollarPartition.Winners(winners);
    }
    
    /// @notice calculates quotas for each cluster starting from scores received by users
    /// @param partition matrix of the clusters in which proposals are divided
    /// @param scoreMap data structure containing the scores
    /// @param k number of winners to select
    /// @return quotas calculated
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

    /// @notice selects the winners from each cluster given the allocation selected
    /// @param partition matrix of the clusters in which proposals are divided
    /// @param scoreMap data structure containing the scores
    /// @param allocation number of winners to select from each cluster
    /// @return selection winners' id and score
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
                winners[x++] = (Utils.Element(partition[i][e.id], e.value));
            }
        }
        return winners;
    }
}
