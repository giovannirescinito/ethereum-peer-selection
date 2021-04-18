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
    /// @param partition zipped matrix of the clusters in which proposals are divided
    function finalizeScoreMap(Scores.ScoreMap storage scoreMap, uint[][] storage partition) external{
        uint[][] memory part = Zipper.unzipMatrix(partition,8);
        uint n = 0;
        for (uint i=0;i<partition.length;i++){
            n += part[i].length;
        }
        uint[] memory row = new uint[](0);
        bool modified;
        uint[] memory eval;
        uint[] memory assign;
        uint[] memory tmp;
        uint[] memory peers;
        for (uint i=0;i<part.length;i++){
            modified = false;
            for (uint j=0;j<part[i].length;j++){
                uint id = part[i][j];
                (peers,) = Scores.reviewsSubmitted(scoreMap, id);
                if (peers.length == 0){
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
                    Scores.setReviews(scoreMap,id,assign,eval);
                }
            }
            if (modified){
                for (uint k=0;k<part[i].length;k++){
                    row[part[i][k]] = 1;
                }
            }
        }
    }

    /// @notice normalize the scores received by a user when revealing and adds them to the corresponding data structure
    /// @param scoreMap data structure containing the scores
    /// @param index index of the agent who submitted the reviews
    /// @param assignments list of the works reviewed
    /// @param evaluations scores provided
    function addToScoreMap(Scores.ScoreMap storage scoreMap, uint index, uint[] calldata assignments, uint[] memory evaluations) external{
        uint sum = 0;
        for (uint j=0;j<assignments.length;j++){
            sum += evaluations[j];
        }
        if (sum != 0){
            for (uint j=0;j<assignments.length;j++){
                evaluations[j] = evaluations[j]*Utils.C/sum;
            }
            Scores.setReviews(scoreMap, index, assignments, evaluations);
        }
    }

    /// @notice calculates quotas for each cluster starting from scores received by users
    /// @param partition zipped matrix of the clusters in which proposals are divided
    /// @param scoreMap data structure containing the scores
    /// @param k number of winners to select
    /// @return quotas calculated
    function calculateQuotas(uint[][] memory partition, Scores.ScoreMap storage scoreMap, uint k) view external returns (uint[] memory){
        uint[][] memory part = Zipper.unzipMatrix(partition,8);
        uint l = part.length;
        uint n = 0;
        for (uint i=0;i<l;i++){
            n+=part[i].length;
        }
        uint[] memory quotas = new uint[](l);
        uint[] memory peers;
        uint[] memory scores;
        for (uint i=0; i<l; i++) {
            quotas[i] = 0;
            for (uint j=0; j<part[i].length; j++){
                (peers,scores) = Scores.reviewsReceived(scoreMap, part[i][j]);
                for (uint x = 0;x<scores.length;x++){
                    quotas[i] += scores[x];
                }
            }
            quotas[i] = quotas[i]*k/n;
        }
        return quotas;
    }

    /// @notice selects the winners from each cluster given the allocation selected
    /// @param partition zipped matrix of the clusters in which proposals are divided
    /// @param scoreMap data structure containing the scores
    /// @param allocation number of winners to select from each cluster
    /// @return selection winners' id and score
    function selectWinners(uint[][] memory partition, Scores.ScoreMap storage scoreMap, uint[] memory allocation) view external returns (Utils.Element[] memory){
        uint[][] memory part = Zipper.unzipMatrix(partition,8);
        uint num = 0;
        for (uint i=0;i<allocation.length;i++){
            num+=allocation[i];
        }
        Utils.Element[] memory scoresSorted;
        Utils.Element[] memory winners = new Utils.Element[](num);
        uint[] memory scores;
        uint[] memory s;
        uint index;
        uint x = 0;
        for (uint i=0; i<part.length; i++) {
            scores = new uint[](part[i].length);
            for (uint j=0; j<part[i].length; j++) {
                (,s) = Scores.reviewsReceived(scoreMap, part[i][j]);
                for (uint k=0; k<s.length; k++) {
                    scores[j] += s[k];
                }
            }
            scoresSorted = Utils.sort(scores);
            index = part[i].length - 1;
            for (uint j=0; j<allocation[i]; j++) {
                Utils.Element memory e = scoresSorted[index--];
                winners[x++] = (Utils.Element(uint128(part[i][e.id]), uint128(e.value)));
            }
        }
        return winners;
    }
}
