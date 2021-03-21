// SPDX-License-Identifier: UNLICENSED

// https://gist.github.com/subhodi/b3b86cc13ad2636420963e692a4d896f

pragma solidity >=0.4.18;
pragma experimental ABIEncoderV2;

library Utils {
    //Constants
    uint constant public C = 10**6;
    
    //Data Structures
    struct Element {
        uint id;
        uint value;
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
    function ceil(uint x) view public returns (uint){
        return ((x + C - 1) / C) * C;
    }

    function floor(uint x) view public returns (uint){
        return (x/C)*C;
    }

    function round(uint x) view public returns (uint){
        if (x-floor(x) < C/2){
            return floor(x);
        }else{
            return ceil(x);
        }
    }

    function range(uint upper) public returns (uint[] memory) {
        uint[] memory a = new uint[](upper);
        for (uint i=0;i<upper;i++){
            a[i] = i;
        }
        return a;
    }
    
    //Sorting functions
    function sort(uint[] memory data) public returns(Element[] memory) {
        Element[] memory dataElements = new Element[](data.length);
        for (uint i=0; i<data.length; i++){
            dataElements[i] = Element(i, data[i]);
        }
       quickSort(dataElements, int(0), int(dataElements.length - 1));
       return dataElements;
    }
    
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

library Proposals {
    //Data Structures
    struct Proposal {
        bytes work;
        uint[] assignment;
        bytes32 commitment;
        uint[] evaluations;
    }

    struct Set {
        Proposal[] elements;
        mapping (bytes32 => uint) idx;
    }

    //Events
    event ProposalSubmitted(bytes32 hashed);
    event ProposalsUpdate(Proposal[] e);
    event Committed(uint tokenId, bytes32 commitment);
    event Revealed(bytes32 commitment,uint randomness, uint[] assignments, uint[] evaluations, uint tokenId);

    modifier checkIndex(Set storage s, uint index) {
        require(index >= 0 && index < s.elements.length, "Set out of bounds"); 
        _;
    }

    //Utility
    function length(Set storage s) public returns (uint) {
        return s.elements.length;
    }

    function encodeWork(bytes memory work) public returns (bytes32){
        return keccak256(abi.encodePacked(work));
    }

    //Setters
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

    function updateAssignment(Set storage s, uint index, uint[] memory assignment) public checkIndex(s, index) {
        s.elements[index].assignment = assignment;
    }

    function setCommitment(Set storage s, uint tokenId, bytes32 com) public checkIndex(s, tokenId - 1){
        s.elements[tokenId - 1].commitment = com;
        emit Committed(tokenId, com);
    }

    function setEvaluations(Set storage s, uint tokenId, uint[] memory assignments, uint[] memory evaluations) public checkIndex(s, tokenId - 1){
        //CONTROLLARE CHE SIANO GLI STESSI ASSIGNMENT???
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
    function getProposals(Set storage s) public returns (Proposal[]memory) {
        return s.elements;
    }

    function getAssignment(Proposal memory p) public returns (uint[] memory) {
        return p.assignment;
    }

    function getWork(Proposal memory p) public returns (bytes memory) {
        return p.work;
    }

    function getCommitment(Proposal memory p) public returns (bytes32){
        return p.commitment;
    }

    function getEvaluations(Proposal memory p) public returns (uint[] memory){
        return p.evaluations;
    }

    function getId(Set storage s, Proposal memory p) public returns (uint){
        return s.idx[encodeWork(p.work)];
    }
    
    function getProposalAt(Set storage s, uint index) public checkIndex(s, index) returns (Proposal memory) {
        return s.elements[index];
    }

    function getProposalByToken(Set storage s, uint tokenId) public returns (Proposal memory){
        return getProposalAt(s, tokenId - 1);
    }
}

library Allocations {
    //Data Structures
    struct Allocation {
        uint[] shares;
        uint p;
    }

    struct Map {
        Allocation[] elements;
        mapping (bytes32 => uint) idx;
    }

    //Events
    event AllocationsGenerated (Allocation[] allocations);
    event AllocationSelected(uint[] allocation);
    
    //Setters
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

    function updateShares(Map storage map, Allocation memory a, uint[] memory shares) public {
        bytes32 h = keccak256(abi.encodePacked(a.shares));
        uint index = map.idx[h];
        require(index != 0, "Allocation not present"); 
        map.elements[index - 1].shares = shares;
    }

    //Getters
    function getAllocations(Map storage map) public returns (Allocation[]memory) {
        return map.elements;
    }

    function getP(Allocation memory a) public returns (uint) {
        return a.p;
    }

    function getShares(Allocation memory a) public returns (uint[] memory) {
        return a.shares;
    }

    function getAllocationAt(Map storage map, uint index) public returns (Allocation memory) {
        require(index >= 0 && index < map.elements.length, "Map out of bounds"); 
        return map.elements[index];
    }

    function getValueInAllocation(Allocation memory a, uint index) public returns (uint) {
        require(index >= 0 && index < a.shares.length, "Allocation out of bounds"); 
        return a.shares[index];
    }
}