// SPDX-License-Identifier: MIT

pragma solidity >=0.4.18;
pragma experimental ABIEncoderV2;


import "contracts/Allocations.sol";
import "contracts/Proposals.sol";
import "contracts/Utils.sol";
import "contracts/Zipper.sol";


/// @title Exact Dollar Partition base implementation
/// @author Giovanni Rescinito
/// @notice implements the operations required to realize an impartial peer selection according to Exact Dollar Partition
library ExactDollarPartition {

    //Events
    event QuotasCalculated(uint[] quotas);
    event AllocationSelected(uint[] allocation);
    event Winners(Utils.Element[] winners);
    
    /// @notice creates a partition of the users consisting in l clusters
    /// @param proposals set containing the collected proposals
    /// @param l number of clusters to generate
    /// @return the zipped partition created, with a row for each cluster
    function createPartition(Proposals.Set storage proposals,  uint l) view external returns (uint[][] memory){
        uint n = Proposals.length(proposals);
        uint size = n/l;
        uint larger = n%l;
        uint[][] memory partition = new uint[][](l);
        uint[] memory agents = Utils.range(n);
        for (uint i=0; i<l; i++){
            uint[] memory tmp;
            if (i<larger){
                tmp = new uint[](size+1);
            }else{
                tmp = new uint[](size);
            }
            for (uint j=i; j<n; j+=l){
                tmp[j/l] = agents[j];
            }
            partition[i] = Zipper.zipArray(tmp,8);
        }
        return partition;
    }
    
    /// @notice generates the assignment according to the rules defined by Exact Dollar Partition
    /// @param partition zipped matrix of the clusters in which proposals are divided
    /// @param proposals set containing the collected proposals
    /// @param m number of reviews to be assigned to each user
    function generateAssignments(uint[][] storage partition, Proposals.Set storage proposals, uint m) external {
        uint l = partition.length;
        uint n = Proposals.length(proposals);
        uint[][] memory assignmentsMap = new uint[][](n);
        uint[][] memory part = Zipper.unzipMatrix(partition,8);
       
        for (uint i=0;i<l;i++){
            require(m <= (n-part[i].length), "Duplicate review required, impossible to create assignments");        
        }

        for (uint i=0;i<l;i++){
            uint len = m* part[i].length;
            uint[] memory clusterAssignment = new uint[](len);
            uint j = 0;
            for (uint k=0;k<len;k++){
                if (i == j){
                    j = (j+1)%l;
                }
                clusterAssignment[k] = j;
                j = (j+1)%l;
            }
       
            for (j=0;j<part[i].length;j++){
                uint[] memory clusters = new uint[](m);
                for (uint k = j*m;k<(j+1)*m;k++){
                    clusters[k%m] = clusterAssignment[k];
                }
                assignmentsMap[part[i][j]] = clusters;
            }
        }
       
        uint[] memory indices = new uint[](l);
        uint index;
        uint[] memory reviewerAssignment = new uint[](m);
        for (uint i=0;i<n;i++){
            for (uint j=0;j<m;j++){
                index = assignmentsMap[i][j];
                reviewerAssignment[j] = part[index][indices[index]];
                indices[index] = (indices[index] + 1) % part[index].length;
            }
            Proposals.updateAssignment(proposals, i, reviewerAssignment);
        }
    }
    

    /// @notice generates integer allocations starting from quotas
    /// @param allocations dictionary used to store the possible allocations found
    /// @param quotas list of real values representing the expected number of winners from each cluster
    function randomizedAllocationFromQuotas(Allocations.Map storage allocations, uint[] memory quotas) external{
        uint n = quotas.length;
        uint[] memory s = new uint[](n);
        uint alpha = 0;
        uint i = 0;
        for (i=0; i<n; i++){
            s[i] = quotas[i] - Utils.floor(quotas[i]);
            alpha += s[i];
        } 
        
        Utils.Element[] memory sSorted = Utils.sort(s);
        for (i=0; i<n; i++){
            s[i] = quotas[sSorted[i].id];
        }
        
        alpha = Utils.round(alpha)/Utils.C;
        uint[] memory allocatedProbability = new uint[](n);
        uint[] memory allocation = new uint[](n);
        uint totalProbability = 0;
        uint low = 0;
        uint high = n-1;
        uint handled = 0;
        
        while (handled <= n){
            for (i=0; i<n; i++){
                allocation[i] = s[i];
                if (i < low){
                    allocation[i] = Utils.floor(allocation[i])/Utils.C;
                }else if ((i >= low) && (i < low + alpha)){
                    allocation[i] = Utils.ceil(allocation[i])/Utils.C;
                }else if ((i >= low + alpha) && (i <= high)){
                    allocation[i] = Utils.floor(allocation[i])/Utils.C;
                }else if (i > high){
                    allocation[i] = Utils.ceil(allocation[i])/Utils.C;
                }
            }
            uint p = 0;
            if (s[low] - Utils.floor(s[low]) - allocatedProbability[low] < Utils.ceil(s[high]) - s[high] - totalProbability + allocatedProbability[high]){
                p = s[low] - Utils.floor(s[low]) - allocatedProbability[low];
                for (i=0; i<n; i++){
                    if (i >= low && i < low + alpha){
                        allocatedProbability[i] += p;
                    }
                    if (i > high){
                        allocatedProbability[i] += p;
                    }
                }
                low += 1;
            }else{
                p = Utils.ceil(s[high]) - s[high] - totalProbability + allocatedProbability[high];
                for (i=0; i<n; i++){
                    if (i >= low && i < low + alpha){
                        allocatedProbability[i] += p;
                    }
                    if (i > high){
                        allocatedProbability[i] += p;
                    }
                }
                high -= 1;
                alpha -= 1;
            }
            totalProbability += p;
            Allocations.setAllocation(allocations,allocation,p);
            handled += 1;
        }   
  
        uint[][] memory a;
        (a,) = Allocations.getAllocations(allocations);
        for (i=0; i<n; i++){
            s = new uint[](n);
            for (uint j=0; j<n; j++){
                s[sSorted[j].id] = a[i][j];
            }
            Allocations.updateShares(allocations, i, s);  
        }
    }

    /// @notice selects an allocation from the dictionary given a random value
    /// @param allocations dictionary containing the possible allocations found
    /// @param p random value in the range [0,C]
    /// @return the winners per cluster from the selected allocation
    function selectAllocation(Allocations.Map storage allocations, uint p) view external returns(uint[] memory){
        uint i = 0;
        uint n = Allocations.length(allocations);
        Allocations.Allocation memory a = Allocations.getAllocationAt(allocations,i); 
        uint currentP = Allocations.getP(a);
        while (p>currentP && i < n - 1){
            a = Allocations.getAllocationAt(allocations,++i); 
            currentP += Allocations.getP(a);
        }
        return Allocations.getShares(a);
    }
}
