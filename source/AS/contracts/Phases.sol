// SPDX-License-Identifier: UNLICENSED


pragma solidity >=0.4.18;
pragma experimental ABIEncoderV2;


import "contracts/ImpartialSelectionInterface.sol";

library Phases{
    enum Phase {Submission, 
                Assignment, 
                Commitment, 
                Reveal, 
                Selection, 
                Completed}

    modifier check(Phase p) {
        checkPhase(p);
        _;
    }

    function checkPhase(Phase p) view public {
        require(ImpartialSelectionInterface(address(this)).getCurrentPhase() == uint8(p), "Different phase than expected"); 
    }

    function changePhase(Phase phase) private {
        ImpartialSelectionInterface(address(this)).setCurrentPhase(uint8(phase));
    }

    function endSubmissionPhase() external check(Phase.Submission) {
        changePhase(Phase.Assignment);
    }

    function endAssignmentPhase() external check(Phase.Assignment) {
        changePhase(Phase.Commitment);
    }

    function endCommitmentPhase() external check(Phase.Commitment){
        changePhase(Phase.Reveal);
    }

    function endRevealPhase() external check(Phase.Reveal){
        changePhase(Phase.Selection);
    }

    function endSelectionPhase() external check(Phase.Selection) {
        changePhase(Phase.Completed);
    }
}