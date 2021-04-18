// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "contracts/Libraries.sol";
import "contracts/Token.sol";

/// @title Impartial Selection base implementation
/// @author Giovanni Rescinito
/// @notice smart contract implementing the base system proposed, using a matrix data structure for scores
contract ImpartialSelection is IERC721Receiver{
    uint[][] scoreMatrix;                       // scores data structure implemented as a matrix
    uint[][] scores;                            // intermediate data structure used during winners selection
    uint[] quotas;                              // real-valued quotas calculated from the scores
    uint[] selectedAllocation;                  // allocation of the winners per cluster selected
    uint[][] partition;                         // matrix of the clusters in which proposals are divided
    uint[][] clusterAssignment;                 // intermediate data structure used during assignment generation
        
    mapping(uint=>uint[]) assignments;          // intermediate data structure used during assignment generation
    
    Phase currentPhase = Phase.SubmissionPhase; // current phase in which the system is
    
    Allocations.Map allocations;                // dictionary containing the possible allocations of winners per cluster
    Proposals.Set proposals;                    // set containing the proposals submitted
    Utils.Element[] winners;                    // selection winners
    Token token;                                // reference to PET token contract

    // Enumeration of the possible execution phases of the system
    enum Phase {SubmissionPhase, 
                AssignmentPhase, 
                CommitmentPhase, 
                RevealPhase, 
                SelectionPhase, 
                CompletedPhase}

    /// @notice checks that the contract's current phase is the expected one
    /// @param p expected phase
    modifier checkPhase(Phase p) {
        require(currentPhase == p, "Different phase than expected"); 
        _;
    }

    /// @notice creates a new instance of the contract and connects the PET token contract
    /// @param tokenAddress address of the PET token to connect to the contract
    constructor(address tokenAddress) public{
        token = Token(tokenAddress);
    }

    /// @notice callback invoked on receiving a token
    /// @param operator the address transferring the token
    /// @param from the owner of the token
    /// @param tokenId the token id
    /// @param data eventual data transferred
    /// @return the selector of the function
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4){
        return this.onERC721Received.selector; 
    }

    /// @notice updates the current phase of the contract
    /// @param phase the phase the contract should be put in
    function changePhase(Phase phase) private {
        currentPhase = phase;
    }

    /// @notice ends submission phase and starts assignment phase
    function endSubmissionPhase() public checkPhase(Phase.SubmissionPhase) {
        changePhase(Phase.AssignmentPhase);
    }

    /// @notice ends assignment phase and starts commitment phase
    function endAssignmentPhase() public checkPhase(Phase.AssignmentPhase) {
        changePhase(Phase.CommitmentPhase);
    }

    /// @notice ends commitment phase and starts reveal phase
    function endCommitmentPhase() public checkPhase(Phase.CommitmentPhase){
        changePhase(Phase.RevealPhase);
    }

    /// @notice ends reveal phase and starts selection phase
    function endRevealPhase() public checkPhase(Phase.RevealPhase){
        changePhase(Phase.SelectionPhase);
    }

    /// @notice ends selection phase and starts completed phase
    function endSelectionPhase() public checkPhase(Phase.SelectionPhase) {
        changePhase(Phase.CompletedPhase);
    }

    /// @notice used to submit a work to the system
    /// @param work the work an agent wishes to submit
    function submitWork(bytes memory work) public checkPhase(Phase.SubmissionPhase){
        Proposals.Proposal memory p = Proposals.propose(proposals, work);
        generateToken(msg.sender, p);
    }

    /// @notice generates a token assigning it to the submitting agent
    /// @param proposer the agent who submitted a work
    /// @param p the proposal the token is related to
    function generateToken(address proposer, Proposals.Proposal memory p) private {
        uint tokenId = Proposals.getId(proposals, p);
        token.mint(proposer, tokenId);
    }

    /// @notice creates a partition of the users consisting in l clusters
    /// @param l number of clusters to generate
    function createPartitions(uint l) public checkPhase(Phase.AssignmentPhase){
        uint n = Proposals.length(proposals);
        uint size = n/l;
        uint larger = n%l;
        
        uint[] memory agents = Utils.range(n);
        for (uint i=0; i<l; i++){
            uint[] memory tmp;
            if (i<larger){
                tmp = new uint[](size+1);
            }else{
                tmp = new uint[](size);
            }
            uint len = tmp.length;
            for (uint j=i; j<n; j+=l){
                tmp[j/l] = agents[j];
            }
            // partition[i] = tmp;
            partition.push(tmp);
        }
        emit Utils.PartitionsGenerated(partition);
    }

    /// @notice provides an externally created partition of the proposals to store on the blockchain
    /// @param part the partition to be stored
    function providePartitions(uint[][] memory part) public{
        partition = part;
        emit Utils.PartitionsGenerated(partition);
    }

    /// @notice generates the assignment according to the rules defined by Exact Dollar Partition
    /// @param m number of reviews to be assigned to each user
    function generateAssignments(uint m) public checkPhase(Phase.AssignmentPhase){
        uint l = partition.length;
        uint n = Proposals.length(proposals);
        for (uint i=0;i<l;i++){
            require(m <= (n-partition[i].length), "Duplicate review required, impossible to create assignments");        
        }

        for (uint i=0;i<l;i++){
            uint len = m* partition[i].length;
            uint[] memory assn = new uint[](len);
            uint j = 0;
            for (uint k=0;k<len;k++){
                if (i == j){
                    j = (j+1)%l;
                }
                assn[k] = j;
                j = (j+1)%l;
            }
            clusterAssignment.push(assn);
        }
        
        for (uint i=0;i<l;i++){
            uint[] memory reviewers = partition[i];
            for (uint j=0;j<partition[i].length;j++){
                uint[] memory clusters = new uint[](m);
                for (uint k = j*m;k<(j+1)*m;k++){
                    clusters[k%m] = clusterAssignment[i][k];
                }
                assignments[partition[i][j]] = clusters;
            }
        }
        
        uint[] memory indices = new uint[](l);
        uint index;
        uint[] memory reviewerAssignment = new uint[](m);
        for (uint i=0;i<n;i++){
            for (uint j=0;j<m;j++){
                index = assignments[i][j];
                reviewerAssignment[j] = partition[index][indices[index]];
                indices[index] = (indices[index] + 1) % partition[index].length;
            }
            Proposals.updateAssignment(proposals, i, reviewerAssignment);
        }
    }

    /// @notice provides an externally created assignment of the reviews to store on the blockchain
    /// @param assignments the assignment to be stored
    function provideAssignments(uint[][] memory assignments) public {
        for (uint i = 0; i<Proposals.length(proposals); i++){
            Proposals.updateAssignment(proposals, i, assignments[i]);
        }
    }
    
    /// @notice getter returning the reviews assignment correponding to a given tokenId
    /// @param tokenId the token id corresponding to the proposal for which the assignment is required
    /// @return the list of proposals assigned for the review to the owner of the token identified by tokenId
    function getAssignmentByToken(uint tokenId) public returns(uint[] memory){
        return Proposals.getAssignment(Proposals.getProposalByToken(proposals, tokenId));
    }

    /// @notice stores a commitment of the evaluations for the assigned reviews on the blockchain, after verifying that the user is authorized
    /// @param commitment the commitment to be stored
    /// @param tokenId the token id associated to the proposal for which the assignment was generated
    function commitEvaluations(bytes32 commitment, uint tokenId) public checkPhase(Phase.CommitmentPhase){
        token.safeTransferFrom(msg.sender, address(this), tokenId);
        Proposals.setCommitment(proposals, tokenId, commitment);
    }

    /// @notice reveals the content of the commitment and checks the correspondance with the one stored on the blockchain
    /// @param tokenId the token id associated to the proposal for which the assignment was generated
    /// @param randomness the randomness used to generate the commitment
    /// @param evaluations the evaluations proposed for the reviews assigned, used to generate the commitment
    /// @return the assignment used to generate the commitment
    function revealEvaluations(uint tokenId, uint randomness, uint[] memory assignments, uint[] memory evaluations) public checkPhase(Phase.RevealPhase){
        bytes32 commitment = Proposals.getCommitment(Proposals.getProposalByToken(proposals,tokenId));
        bytes32 hashed = keccak256(abi.encodePacked(randomness,assignments,evaluations));
        require(hashed == commitment, "Incorrect data to reveal");
        emit Proposals.Revealed(commitment,randomness,assignments,evaluations, tokenId);
        Proposals.setEvaluations(proposals,tokenId,assignments,evaluations);
    }

    /// @notice contructs the scores matrix starting from the evaluations submitted by agents 
    function constructScoreMatrix() public checkPhase(Phase.SelectionPhase){
        uint n = Proposals.length(proposals);
        Proposals.Proposal[] memory p = Proposals.getProposals(proposals);
        for (uint i = 0;i<n;i++){
            scoreMatrix.push(new uint[](n));
        }
        for (uint i = 0;i<n;i++){
            uint[] memory e = Proposals.getEvaluations(p[i]);
            if (e.length > 0){
                uint[] memory a = Proposals.getAssignment(p[i]);
                for (uint j=0;j<a.length;j++){
                    scoreMatrix[a[j]][i] = e[j];
                }
            }
        }
        emit Utils.ScoreMatrixConstructed(scoreMatrix);
    }
    
    /// @notice executes the actual selection by invoking Exact Dollar Partition
    /// @param k number of winners to select
    /// @param normalize indicates if the scores have to be normalized
    function exactDollarPartition(uint k, bool normalize) public checkPhase(Phase.SelectionPhase){
        uint l = partition.length;
        uint n = uint(scoreMatrix[0].length);
        emit Utils.AlgorithmInfo(k, n, l);

        quotas = new uint[](l);
        
        if (normalize){
            normalizeScoreMatrix();
        }
        emit Utils.ScoreMatrixConstructed(scoreMatrix);

        calculateQuotas(k);
        emit Utils.QuotasCalculated(quotas);

        randomizedAllocationFromQuotas();
        emit Allocations.AllocationsGenerated(Allocations.getAllocations(allocations));

        uint random = 800000;
        selectedAllocation = selectAllocation(random);
        emit Allocations.AllocationSelected(selectedAllocation);

        selectWinners(selectedAllocation);
        emit Utils.Winners(winners);
    }

    /// @notice normalizes the score matrix
    function normalizeScoreMatrix() private{
        uint l = partition.length;
        uint n = uint(scoreMatrix[0].length);
        uint[] memory colSums = new uint[](n);
        for (uint i=0; i<n; i++){
            for (uint j=0; j<n; j++){
                colSums[j] += scoreMatrix[i][j];
                scoreMatrix[i][j] *= Utils.C;
            }
        }
        if (partition.length != 0){
            for (uint i=0; i<l; i++){
                for (uint j=0; j<partition[i].length; j++){
                    if (colSums[(partition[i][j])] == 0){
                        for (uint k=0; k<l; k++){
                            if (k != i){
                                for (uint q=0; q<partition[k].length; q++){
                                    scoreMatrix[(partition[k][q])][j] = Utils.C;
                                }
                            }
                        }
                    }
                }
            }
        }else{
            for (uint j=0; j<n; j++){
                if (colSums[j] == 0){
                    for (uint i=0; i<n; i++){
                        scoreMatrix[i][j] = Utils.C;
                    }
                }
                scoreMatrix[j][j] = 0;
            }
        }
        
        for (uint j=0; j<n; j++){
            if (colSums[j] == 0){
                for (uint i=0; i<n; i++){
                    colSums[j] += scoreMatrix[i][j]/Utils.C;
                }
            }
        }
        
        for (uint i=0; i<n; i++){
            for (uint j=0; j<n; j++){
                scoreMatrix[i][j] = scoreMatrix[i][j]/colSums[j];
            }
        }
    }
    
    /// @notice calculates quotas for each cluster starting from scores received by users
    /// @param k number of winners to select
    /// @return quotas calculated
    function calculateQuotas(uint k) private{
        uint l = partition.length;
        uint n = uint(scoreMatrix[0].length);
        uint[] memory dist = new uint[](l);
        for (uint i=0; i<l; i++) {
            dist[i] = 0;
            for (uint j=0; j<l; j++) {
                if (i != j){
                    uint t = 0;
                    for (uint x=0; x<partition[i].length; x++){
                        for (uint y=0; y<partition[j].length; y++){
                            t += scoreMatrix[(partition[i][x])][(partition[j][y])];
                        }
                    }
                    dist[i] += t;
                }
            }
        }
        
        for (uint i=0; i<l; i++) {
            quotas[i] = dist[i]*k/n;
        }
    }

    /// @notice generates integer allocations starting from quotas
    function randomizedAllocationFromQuotas() private{
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
            }
            for (i=0; i<n; i++){
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
                }
                for (i=0; i<n; i++){
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
                }
                for (i=0; i<n; i++){
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
  
        uint[] memory sortedVec;
        Allocations.Allocation memory a;
        for (i=0; i<n; i++){
            a = Allocations.getAllocationAt(allocations,i);
            sortedVec = new uint[](n);
            for (uint j=0; j<n; j++){
                sortedVec[sSorted[j].id] = Allocations.getValueInAllocation(a, j);
            }
            Allocations.updateShares(allocations, a, sortedVec);    
        }
    }

    /// @notice selects an allocation from the dictionary given a random value
    /// @param p random value in the range [0,C]
    /// @return the winners per cluster from the selected allocation
    function selectAllocation(uint p) private returns(uint[] memory){
        uint i = 0;
        Allocations.Allocation memory a = Allocations.getAllocationAt(allocations,i); 
        uint currentP = Allocations.getP(a);
        while (p>currentP){
            i+=1;
            a = Allocations.getAllocationAt(allocations,i); 
            currentP += Allocations.getP(a);
        }
        return Allocations.getShares(a);
    }

    /// @notice selects the winners from each cluster given the allocation selected
    /// @param allocation number of winners to select from each cluster
    function selectWinners(uint[] memory allocation) private{
        Utils.Element[] memory scoresSorted;
        Utils.Element memory e;
        uint score = 0;
        uint index;
        for (uint i=0; i<partition.length; i++) {
            scores.push(new uint[](partition[i].length));
            for (uint j=0; j<partition[i].length; j++) {
                for (uint k=0; k<scoreMatrix.length; k++) {
                    score += scoreMatrix[partition[i][j]][k];
                }
                scores[i][j] = score;
                score = 0;
            }
            // For each cluster, sorts the scores received by its users and selects the ones having the highest score
            // according to the allocation drawn
            scoresSorted = Utils.sort(scores[i]);
            index = partition[i].length - 1;
            for (uint q=0; q<allocation[i]; q++) {
                e = scoresSorted[index];
                winners.push(Utils.Element(partition[i][e.id], e.value));
                index--;
            }
        }
    }
}