// SPDX-License-Identifier: UNLICENSED


pragma solidity >=0.4.18;
pragma experimental ABIEncoderV2;

library Proposals{
    //Data Structures
    struct Proposal {
        uint[] assignment;
        bytes32 commitment;
        bytes work;
    }

    struct Set {
        Proposal[] elements;
        mapping (bytes32 => uint) idx;
        mapping (uint => uint) tokenToIndex;
    }

    //Events
    event ProposalSubmitted(bytes32 hashedWork, uint ID);
    event Committed(uint tokenId, bytes32 commitment);
    event Revealed(bytes32 commitment,uint randomness, uint[] assignments, uint[] evaluations, uint tokenId);

    modifier checkIndex(Set storage s, uint index) {
        require(index >= 0 && index < s.elements.length, "Set out of bounds"); 
        _;
    }

    //Utility
    function length(Set storage s) view external returns (uint) {
        return s.elements.length;
    }

    function encodeWork(bytes calldata work) pure private returns (bytes32){
        return keccak256(abi.encodePacked(work));
    }

    //Setters
    function propose(Set storage s, bytes calldata work) external returns (Proposal memory){
        bytes32 h = encodeWork(work);
        uint index = s.idx[h];
        require(index == 0, "Work already proposed"); 
        Proposal memory p = Proposal(new uint[](0), 0x0, work);
        s.elements.push(p);
        index = s.elements.length;
        s.idx[h] = index;
        emit ProposalSubmitted(h, index - 1);
        return p;
    }

    function updateAssignment(Set storage s, uint index, uint[] calldata assignment) external checkIndex(s, index) {
        s.elements[index].assignment = assignment;
    }

    function setToken(Set storage s, Proposal calldata p, uint tokenId) external{
        s.tokenToIndex[tokenId] = getId(s, p);
    }

    function setCommitment(Set storage s, uint tokenId, bytes32 com)  external{
        uint id = getIdFromToken(s,tokenId);
        require(id >= 0 && id < s.elements.length, "Set out of bounds"); 
        s.elements[id].commitment = com;
        emit Committed(tokenId, com);
    }

    //Getters
    function getAssignment(Proposal calldata p) pure external returns (uint[] memory) {
        return p.assignment;
    }

    function getWork(Proposal calldata p) pure external returns (bytes memory) {
        return p.work;
    }

    function getCommitment(Proposal calldata p) pure external returns (bytes32){
        return p.commitment;
    }

    function getId(Set storage s, Proposal calldata p) view private returns (uint){
        return s.idx[encodeWork(p.work)];
    }

    function getIdFromToken(Set storage s, uint tokenId) view public returns (uint){
        uint id = s.tokenToIndex[tokenId];
        require(id != 0, "Token unavailable");
        return id - 1;
    }
    
    function getProposalAt(Set storage s, uint index) view public checkIndex(s, index) returns (Proposal memory) {
        return s.elements[index];
    }

    function getProposalByToken(Set storage s, uint tokenId) view public returns (Proposal memory){
        return getProposalAt(s, getIdFromToken(s,tokenId));
    }

    function getAssignmentByToken(Set storage s, uint tokenId) view external returns (uint[] memory) {
        Proposal memory p = getProposalByToken(s, tokenId);
        return p.assignment;
    }
}