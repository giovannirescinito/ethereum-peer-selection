// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "contracts/Allocations.sol";
import "contracts/ExactDollarPartition.sol";
import "contracts/Phases.sol";
import "contracts/Proposals.sol";
import "contracts/Zipper.sol";

import "contracts/Token.sol";
import "contracts/ImpartialSelectionInterface.sol";

contract ImpartialSelection is IERC721Receiver, ImpartialSelectionInterface, AccessControl{
    uint[][] internal partition;
    uint8 internal currentPhase = 0;
    Allocations.Map internal allocations;  
    Proposals.Set internal proposals;    
    Token internal token;

    modifier authorized(){
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Unauthorized operation");
        _;
    }

    constructor(address tokenAddress) public{
        token = Token(tokenAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());    
    }

    function isImpartialSelection() external view override returns(bool){
        return (address(token) == msg.sender);
    }

    function finalizeCreation() external override{
        grantRole(DEFAULT_ADMIN_ROLE,address(this));
        token.addMinter();    
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4){
        return this.onERC721Received.selector; 
    }

    function getTokenAddress() external view override returns (address){
        return address(token);
    }

    function setCurrentPhase(uint8 p) external override authorized(){
        require (p == currentPhase + 1, "Jumping between phases" );
        currentPhase = p;
    }

    function getCurrentPhase() external view override returns (uint8){
        return currentPhase;
    }

    function endSubmissionPhase() external override authorized(){
        Phases.endSubmissionPhase();
        Proposals.calculateOptimalWidth(proposals);
    }

    function endAssignmentPhase() external override authorized(){
        Phases.endAssignmentPhase();
    }

    function endCommitmentPhase() public virtual override authorized(){
        Phases.endCommitmentPhase();
    }

    function endRevealPhase() public virtual override authorized(){
        Phases.endRevealPhase();
    }

    function endSelectionPhase() external override authorized(){
        Phases.endSelectionPhase();
    }

    function getPartition() external view override returns(uint[][] memory){
        return Zipper.unzipMatrix(partition,Proposals.getOptimalWidth(proposals));
    }
    
    function getAllocations() external view override returns (uint[][] memory, uint[] memory){
        return Allocations.getAllocations(allocations);
    }

    function getAssignmentByToken(uint tokenId) external view override returns(uint[] memory){
        return Proposals.getAssignmentByToken(proposals, tokenId);
    }

    function getAssignmentById(uint id) external view override returns(uint[] memory){
        return Proposals.getAssignment(proposals,Proposals.getProposalAt(proposals, id));
    }

    function getWorkById(uint id) external view override returns(bytes memory){
        return Proposals.getWork(Proposals.getProposalAt(proposals, id));
    }

    function submitWork(bytes calldata work) external override{
        Phases.checkPhase(Phases.Phase.Submission);
        Proposals.Proposal memory p = Proposals.propose(proposals, work);
        uint tokenId = token.mint(msg.sender);
        Proposals.setToken(proposals, p, tokenId);
    }

    function createPartition(uint l) external override authorized(){
        Phases.checkPhase(Phases.Phase.Assignment);
        partition = ExactDollarPartition.createPartition(proposals, l);
    }

    function providePartition(uint[][] calldata part) external override authorized(){
        Phases.checkPhase(Phases.Phase.Assignment);
        partition = Zipper.zipMatrix(part,Proposals.getOptimalWidth(proposals));
    }

    function generateAssignments(uint m) external override authorized(){
        Phases.checkPhase(Phases.Phase.Assignment);
        require(partition.length!=0,"Paritition uninitialized");
        ExactDollarPartition.generateAssignments(partition,proposals,m);
    }
    
    function provideAssignments(uint[][] calldata assignments ) external override authorized(){
        Phases.checkPhase(Phases.Phase.Assignment);
        uint n = Proposals.length(proposals);
        require(n == assignments.length, "Different number of assignments than proposals");
        for (uint i = 0; i<n; i++){
            Proposals.updateAssignment(proposals, i, assignments[i]);
        }
    }
    
    function commitEvaluations(bytes32 commitment, uint tokenId) external override{
        Phases.checkPhase(Phases.Phase.Commitment);
        token.safeTransferFrom(msg.sender, address(this), tokenId);
        Proposals.setCommitment(proposals, tokenId, commitment);
    }

    function revealEvaluations(uint tokenId, uint randomness, uint[] calldata evaluations) public virtual override returns (uint[] memory){
        Phases.checkPhase(Phases.Phase.Reveal);
        Proposals.Proposal memory p = Proposals.getProposalByToken(proposals,tokenId);
        bytes32 commitment = Proposals.getCommitment(p);
        require (commitment != bytes32(0), "Commitment not set");
        uint[] memory assignments = Proposals.getAssignment(proposals,p);
        require(assignments.length == evaluations.length, "Incoherent dimensions between assignments and evaluations");
        require(keccak256(abi.encodePacked(randomness,assignments,evaluations)) == commitment, "Incorrect data to reveal");
        emit Proposals.Revealed(commitment,randomness,assignments,evaluations, tokenId);
        return assignments;
    }

    function impartialSelection(uint k, uint randomness) public virtual override authorized(){
        Phases.checkPhase(Phases.Phase.Selection);        
        require(k <= Proposals.length(proposals), "More winners than participants");
    }
}