// SPDX-License-Identifier: MIT

pragma solidity >=0.4.18;
pragma experimental ABIEncoderV2;

/// @title Utility functions
/// @author Giovanni Rescinito
/// @notice math utilities and sorting functions
library Utils {
    //Constants
    uint constant public C = 10**6;     // constant used to scale value
    
    //Data Structures

    /// @notice container used to maintain agent id and score together
    struct Element {
        uint id;            // agent id
        uint value;         // score
    }

    //Events
    event ClustersAssignmentsGenerated(uint[][] assignments);
    event AssignmentGenerated(uint[] assignments);
    event PartitionsGenerated(uint[][] partition);
    event AlgorithmInfo(uint nWinners, uint matrixSizes, uint nPartitions);
    event ScoreMatrixConstructed(uint[][] scoreMatrix);
    event QuotasCalculated(uint[] quotas);
    event Winners(Element[] winners);
    
    //Math functions

    /// @notice returns the smallest integer value that is bigger than or equal to a number, using scaling by C
    /// @param x the value to be rounded
    /// @return the rounded value
    function ceil(uint x) view public returns (uint){
        return ((x + C - 1) / C) * C;
    }

    /// @notice returns the largest integer value that is less than or equal to a number, using scaling by C
    /// @param x the value to be rounded
    /// @return the rounded value
    function floor(uint x) view public returns (uint){
        return (x/C)*C;
    }

    /// @notice returns the nearest integer to a number, using scaling by C
    /// @param x the value to be rounded
    /// @return the rounded value
    function round(uint x) view public returns (uint){
        if (x-floor(x) < C/2){
            return floor(x);
        }else{
            return ceil(x);
        }
    }

    /// @notice produces a range of n values, from 0 to n-1
    /// @param upper the number values to produce
    /// @return a list of integer values, from 0 to upper-1
    function range(uint upper) public returns (uint[] memory) {
        uint[] memory a = new uint[](upper);
        for (uint i=0;i<upper;i++){
            a[i] = i;
        }
        return a;
    }
    
    //Sorting functions

    /// @notice sorts a list of values in ascending order
    /// @param data the list of values to order
    /// @return the ordered values with the corresponding ordered indices
    /// base implementation provided by https://gist.github.com/subhodi/b3b86cc13ad2636420963e692a4d896f
    function sort(uint[] memory data) public returns(Element[] memory) {
        Element[] memory dataElements = new Element[](data.length);
        for (uint i=0; i<data.length; i++){
            dataElements[i] = Element(i, data[i]);
        }
       quickSort(dataElements, int(0), int(dataElements.length - 1));
       return dataElements;
    }
    
    /// @notice implements sorting using quicksort algorithm
    /// @param arr the list of elements to order
    /// @param left the starting index of the subset of values ordered
    /// @param right the final index of the subset of values ordered
    /// base implementation provided by https://gist.github.com/subhodi/b3b86cc13ad2636420963e692a4d896f
    function quickSort(Element[] memory arr, int left, int right) internal{
        int i = left;
        int j = right;
        if(i==j) return;
        uint pivot = arr[uint(left + (right - left) / 2)].value;
        while (i <= j) {
            while (arr[uint(i)].value < pivot) i++;
            while (pivot < arr[uint(j)].value) j--;
            if (i <= j) {
                (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
                i++;
                j--;
            }
        }
        if (left < j)
            quickSort(arr, left, j);
        if (i < right)
            quickSort(arr, i, right);
    }
}

/// @title Set containing proposals
/// @author Giovanni Rescinito
/// @notice proposals submitted by agents, along with the corresponding assignment and commitment
library Proposals{
    //Data Structures

    /// @notice Data structure related to a single proposal
    struct Proposal {
        bytes work;             // work submitted
        uint[] assignment;      // assignment associated to the proposal
        bytes32 commitment;     // commitment associated to the proposal
        uint[] evaluations;     // evaluations associated to the proposal
    }

    /// @notice Set data structure containing proposals
    struct Set {
        Proposal[] elements;                    // list of the proposals submitted
        mapping (bytes32 => uint) idx;          // maps the proposal to the index in the list
    }

    //Events
    event ProposalSubmitted(bytes32 hashed);
    event ProposalsUpdate(Proposal[] e);
    event Committed(uint tokenId, bytes32 commitment);
    event Revealed(bytes32 commitment,uint randomness, uint[] assignments, uint[] evaluations, uint tokenId);

    /// @notice checks that the index corresponds to an existing value in the set
    /// @param s the set to check
    /// @param index the index to check
    modifier checkIndex(Set storage s, uint index) {
        require(index >= 0 && index < s.elements.length, "Set out of bounds"); 
        _;
    }

    //Utility

    /// @notice returns the number of proposals submitted
    /// @param s set containing proposals
    /// @return the length of the list contained in the set
    function length(Set storage s) public returns (uint) {
        return s.elements.length;
    }

    /// @notice hashes the work submitted to obtain the index of the set
    /// @param work the work to be hashed
    /// @return the keccak256 hash of the work
    function encodeWork(bytes memory work) public returns (bytes32){
        return keccak256(abi.encodePacked(work));
    }

    //Setters

    /// @notice stores a proposal in the set
    /// @param s set containing proposals
    /// @param work the work submitted
    /// @return the proposal created from the work
    function propose(Set storage s, bytes memory work) public returns (Proposal memory){
        bytes32 h = encodeWork(work);
        uint index = s.idx[h];
        require(index == 0, "Work already proposed"); 
        Proposal memory p = Proposal(work,new uint[](0), 0x0,new uint[](0));
        s.elements.push(p);
        s.idx[h] = s.elements.length;
        emit ProposalSubmitted(h);
        return p;
    }

    /// @notice updates the assignment in the set given a specific index
    /// @param s set containing proposals
    /// @param index index in the list of elements of the set to update
    /// @param assignment the assignment to be stored
    function updateAssignment(Set storage s, uint index, uint[] memory assignment) public checkIndex(s, index) {
        s.elements[index].assignment = assignment;
    }

    /// @notice stores the commitment in the proposal considered
    /// @param s set containing proposals
    /// @param tokenId token associated to the proposal for which the evaluations' commitment should be stored
    /// @param com the commitment to save
    function setCommitment(Set storage s, uint tokenId, bytes32 com) public checkIndex(s, tokenId - 1){
        s.elements[tokenId - 1].commitment = com;
        emit Committed(tokenId, com);
    }

    /// @notice stores the evaluations related to the proposal considered
    /// @param s set containing proposals
    /// @param tokenId token associated to the proposal for which the evaluations should be stored
    /// @param assignments the assignment considered
    /// @param evaluations the evaluations proposed
    function setEvaluations(Set storage s, uint tokenId, uint[] memory assignments, uint[] memory evaluations) public checkIndex(s, tokenId - 1){
        require(assignments.length == evaluations.length, "Incoherent dimensions between assignments and evaluations");
        Proposal storage p = s.elements[tokenId - 1];
        p.assignment = assignments;
        p.evaluations = new uint[](assignments.length);
        for (uint i=0; i<assignments.length;i++){
            p.evaluations[i] = evaluations[i];
        }
        emit ProposalsUpdate(s.elements);
    }

    //Getters

    /// @param s set containing proposals
    /// @return the list of proposals stored in the set
    function getProposals(Set storage s) public returns (Proposal[]memory) {
        return s.elements;
    }

    /// @param p proposal considered
    /// @return the assignment associated to the proposal
    function getAssignment(Proposal memory p) public returns (uint[] memory) {
        return p.assignment;
    }

    /// @param p proposal considered
    /// @return the work associated to the proposal
    function getWork(Proposal memory p) public returns (bytes memory) {
        return p.work;
    }

    /// @param p proposal considered
    /// @return the commitment associated to the proposal
    function getCommitment(Proposal memory p) public returns (bytes32){
        return p.commitment;
    }

    /// @param p proposal considered
    /// @return the evaluations associated to the proposal
    function getEvaluations(Proposal memory p) public returns (uint[] memory){
        return p.evaluations;
    }

    /// @param s set containing proposals
    /// @param p proposal considered
    /// @return the index associated to the proposal
    function getId(Set storage s, Proposal memory p) public returns (uint){
        return s.idx[encodeWork(p.work)];
    }
    
    /// @param s set containing proposals
    /// @param index the index in the list of proposals
    /// @return the proposal associated to the index in the list
    function getProposalAt(Set storage s, uint index) public checkIndex(s, index) returns (Proposal memory) {
        return s.elements[index];
    }

    /// @param s set containing proposals
    /// @param tokenId the token associated to the proposal
    /// @return the proposal associated to the token provided
    function getProposalByToken(Set storage s, uint tokenId) public returns (Proposal memory){
        return getProposalAt(s, tokenId - 1);
    }
}

/// @title Dictionary storing allocations
/// @author Giovanni Rescinito
/// @notice Data structure implemented as an iterable map, produced during the apportionment algorithm to store allocations
library Allocations {
    //Data Structures

    /// @notice Data structure related to a single allocation
    struct Allocation {
        uint[] shares;      // winners per cluster
        uint p;             // probability of the allocation
    }

    /// @notice Dictionary containing allocations
    struct Map {
        Allocation[] elements;          // list of allocations
        mapping (bytes32 => uint) idx;  // maps key to index in the list
    }

    //Events
    event AllocationsGenerated (Allocation[] allocations);
    event AllocationSelected(uint[] allocation);
    
    //Setters

    /// @notice creates a new allocation or updates the probability of an existing one
    /// @param map dictionary containing allocations
    /// @param a winners per cluster to insert/modify
    /// @param p probability of the specific allocation
    function setAllocation(Map storage map, uint[] memory a, uint p) public {
        bytes32 h = keccak256(abi.encodePacked(a));
        uint index = map.idx[h];
        if (index == 0) {
            map.elements.push(Allocation(a, p));
            map.idx[h] = map.elements.length;
        }else {
            map.elements[index - 1].p = p;
        }
    }

    /// @notice updates the winners per cluster of an allocation specified by its index
    /// @param map dictionary containing allocations
    /// @param index index of the allocation to modify
    /// @param shares winners per cluster to update
    function updateShares(Map storage map, Allocation memory a, uint[] memory shares) public {
        bytes32 h = keccak256(abi.encodePacked(a.shares));
        uint index = map.idx[h];
        require(index != 0, "Allocation not present"); 
        map.elements[index - 1].shares = shares;
    }

    //Getters
    
    /// @param map dictionary containing allocations
    /// @return the list of allocations stored
    function getAllocations(Map storage map) public returns (Allocation[]memory) {
        return map.elements;
    }

    /// @param a allocation for which the probability is required
    /// @return the probability associated to the allocation
    function getP(Allocation memory a) public returns (uint) {
        return a.p;
    }

    /// @param a allocation for which the winners per cluster are required
    /// @return the winners per cluster associated to the allocation
    function getShares(Allocation memory a) public returns (uint[] memory) {
        return a.shares;
    }

    /// @param map dictionary containing allocations
    /// @param index allocation for which the probability is required
    /// @return the allocation stored at a specified index
    function getAllocationAt(Map storage map, uint index) public returns (Allocation memory) {
        require(index >= 0 && index < map.elements.length, "Map out of bounds"); 
        return map.elements[index];
    }

    /// @param a allocation from which the winners per cluster are needed
    /// @param index cluster to select
    /// @return the number of winners in a specified allocation for a fixed cluster
    function getValueInAllocation(Allocation memory a, uint index) public returns (uint) {
        require(index >= 0 && index < a.shares.length, "Allocation out of bounds"); 
        return a.shares[index];
    }
}