// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "contracts/Libraries.sol";
import "contracts/Token.sol";


contract ImpartialSelection is IERC721Receiver{
    uint[][] scoreMatrix;
    uint[][] scores;
    uint[] quotas;
    uint[] selectedAllocation;
    uint[][] partition;
    uint[][] clusterAssignment;
        
    mapping(uint=>uint[]) assignments;
    
    Phase currentPhase = Phase.SubmissionPhase;
    
    Allocations.Map allocations;  
    Proposals.Set proposals;    
    Utils.Element[] winners;
    Token token;

    enum Phase {SubmissionPhase, 
                AssignmentPhase, 
                CommitmentPhase, 
                RevealPhase, 
                SelectionPhase, 
                CompletedPhase}

    modifier checkPhase(Phase p) {
        require(currentPhase == p, "Different phase than expected"); 
        _;
    }

    constructor(address tokenAddress) public{
        token = Token(tokenAddress);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4){
        return this.onERC721Received.selector; 
    }

    function changePhase(Phase phase) private {
        currentPhase = phase;
    }

    function endSubmissionPhase() public checkPhase(Phase.SubmissionPhase) {
        changePhase(Phase.AssignmentPhase);
    }

    function endAssignmentPhase() public checkPhase(Phase.AssignmentPhase) {
        changePhase(Phase.CommitmentPhase);
    }

    function endCommitmentPhase() public checkPhase(Phase.CommitmentPhase){
        changePhase(Phase.RevealPhase);
    }

    function endRevealPhase() public checkPhase(Phase.RevealPhase){
        changePhase(Phase.SelectionPhase);
    }

    function endSelectionPhase() public checkPhase(Phase.SelectionPhase) {
        changePhase(Phase.CompletedPhase);
    }

    function submitWork(bytes memory work) public checkPhase(Phase.SubmissionPhase){
        Proposals.Proposal memory p = Proposals.propose(proposals, work);
        generateToken(msg.sender, p);
    }

    function generateToken(address proposer, Proposals.Proposal memory p) private {
        uint tokenId = Proposals.getId(proposals, p);
        token.mint(proposer, tokenId);
    }

    function createPartitions(uint l) public checkPhase(Phase.AssignmentPhase){
        uint n = Proposals.length(proposals);
        uint size = n/l;
        uint larger = n%l;
        
        uint[] memory agents = Utils.range(n);
        //INSERIRE SHUFFLE
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

    function providePartitions(uint[][] memory part) public{
        partition = part;
        emit Utils.PartitionsGenerated(partition);
    }

    function generateAssignments(uint m) public checkPhase(Phase.AssignmentPhase){
        // if clusters != {}:
        //     #Ensure that the partitions don't overlap.
        //     agent_set = list(itertools.chain(*clusters.values()))
        //     if len(agent_set) != len(set(agent_set)):
        //         print("clustering contains duplicates in different clusters")
        //         return 0
        // else:
        //     #Make everone their own cluster if we don't have a clustering.
        //     clusters = {i:[agents[i]] for i in range(len(agents))}

        uint l = partition.length;
        uint n = Proposals.length(proposals);
        //SHUFFLE CLUSTERS
        
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
            //SHUFFLE ASSN???
            clusterAssignment.push(assn);
        }
        
        for (uint i=0;i<l;i++){
            uint[] memory reviewers = partition[i];
            //SHUFFLE REVIEWERS
            for (uint j=0;j<partition[i].length;j++){
                uint[] memory clusters = new uint[](m);
                for (uint k = j*m;k<(j+1)*m;k++){
                    clusters[k%m] = clusterAssignment[i][k];
                }
                assignments[partition[i][j]] = clusters;
            }
        }
        
        for (uint i=0; i<l; i++){
            //SHUFFLE ELEMENTI DELLE SINGOLE PARTIZIONI???            
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

        // emit Proposals.ProposalsUpdate(Proposals.getProposals(proposals));
        
        //emit Utils.ClustersAssignmentsGenerated(clusterAssignment);
        
        // # Post check for duplicates..
        // for k,v in agent_assignment.items():
        //     if len(v) != len(set(v)):
        //     print("Double review assignment: ", str(k), " :: ", str(v))
        //     if len(v) != m:
        //     print("Error in assignment, agent ", str(k), " has less than m reviews ", str(v))
        // if _DEBUG: print("Agent to Agent: " + str(agent_assignment))

        // return agent_assignment
    }

    function provideAssignments(uint[][] memory assignments ) public {
        for (uint i = 0; i<Proposals.length(proposals); i++){
            Proposals.updateAssignment(proposals, i, assignments[i]);
        }
    }
    
    function getAssignmentByToken(uint tokenId) public returns(uint[] memory){
        return Proposals.getAssignment(Proposals.getProposalByToken(proposals, tokenId));
    }

    function commitEvaluations(bytes32 commitment, uint tokenId) public checkPhase(Phase.CommitmentPhase){
        token.safeTransferFrom(msg.sender, address(this), tokenId);
        Proposals.setCommitment(proposals, tokenId, commitment);
    }

    function revealEvaluations(uint tokenId, uint randomness, uint[] memory assignments, uint[] memory evaluations) public checkPhase(Phase.RevealPhase){
        bytes32 commitment = Proposals.getCommitment(Proposals.getProposalByToken(proposals,tokenId));
        bytes32 hashed = keccak256(abi.encodePacked(randomness,assignments,evaluations));
        require(hashed == commitment, "Incorrect data to reveal");
        emit Proposals.Revealed(commitment,randomness,assignments,evaluations, tokenId);
        Proposals.setEvaluations(proposals,tokenId,assignments,evaluations);
    }

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
    
    function exactDollarPartition(uint k, bool normalize) public checkPhase(Phase.SelectionPhase){
        uint l = partition.length;
        uint n = uint(scoreMatrix[0].length);
        emit Utils.AlgorithmInfo(k, n, l);

        quotas = new uint[](l);
        /*scoreMatrix = validateMatrix(partition);
        if isinstance(scoreMatrix, int):
            return 0
        */

        if (normalize){
            normalizeScoreMatrix();
        }
        emit Utils.ScoreMatrixConstructed(scoreMatrix);

        calculateQuotas(k);
        // quotas = [1100000,2100000,1300000,1700000,1800000];
        emit Utils.QuotasCalculated(quotas);

        randomizedAllocationFromQuotas();
        emit Allocations.AllocationsGenerated(Allocations.getAllocations(allocations));

        uint random = 800000;
        selectedAllocation = selectAllocation(random);
        emit Allocations.AllocationSelected(selectedAllocation);

        selectWinners(selectedAllocation);
        emit Utils.Winners(winners);
    }
    
    function validateMatrix() private{
        require(scoreMatrix.length == scoreMatrix[0].length, "Score Matrix is not square");
        
    }
    
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
           /*
            norm_scoreMatrix = scoreMatrix / colSums[np.newaxis , : ]
            # We may still have nan's because everyone's in one partition...
            norm_scoreMatrix = np.nan_to_num(norm_scoreMatrix)
            if _DEBUG: print("\nnormalized score matrix:\n" + str(norm_scoreMatrix))
            return norm_scoreMatrix
            */
    }

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

        //uint id;
        for (i=0; i<n; i++){
            //id = sSorted[i].id;
            //s[i] = quotas[id];
            s[i] = quotas[sSorted[i].id];
            //quotas sorted
        }
        
        /*
        if not np.isclose(alpha, int(round(alpha))):
            print("Alpha is " + str(alpha) + " too far from an integer.")
            exit(0)
        */

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
        
        /*if not np.isclose(sum(distribution.values()), 1.0):
            print("Didn't get a distribution on allocation.  Allocated " + str(sum(distribution.values())) + ", should be near 1.0.")
            exit(0)
        */
            
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

    function selectWinners(uint[] memory allocation) private{
        /*
        if score_matrix.ndim != 2 or score_matrix.shape[0] != score_matrix.shape[1]:
            print("score_matrix is not square or has no values")
            return 0
        if sum(elements) > score_matrix.shape[0] or sum(elements) <= 0:
            print("must select more winners than shape or no winners")
            return 0
        */

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