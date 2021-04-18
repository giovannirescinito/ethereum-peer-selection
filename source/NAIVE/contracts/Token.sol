// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Pausable.sol";

/// @title Proposal Evaluation Token
/// @author Giovanni Rescinito
/// @notice ERC721 token used to authorize agents to commit their evaluations
contract Token is Context, AccessControl, ERC721Burnable, ERC721Pausable {
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");     // constant used to identify minters
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");     // constant used to identify pausers
    
    event TokenAssigned(address to, uint tokenId);
    
    /// @notice creates a new instance of the token contract
    /// @param name name of the token created
    /// @param symbol symbol associated to the token
    /// @param baseURI uri used as a prefix to identify tokens through strings
    constructor(string memory name, string memory symbol, string memory baseURI) public ERC721(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());

        _setBaseURI(baseURI);
    }

    /// @notice grants the minter, pauser and admin role to the invoking contract
    /// @param _newOwner address receiving the roles
    function transferOwnership(address _newOwner) public {
        require(hasRole(DEFAULT_ADMIN_ROLE,_msgSender()));
        grantRole(MINTER_ROLE, _newOwner);
        grantRole(PAUSER_ROLE, _newOwner);
        grantRole(DEFAULT_ADMIN_ROLE, _newOwner);
    }

    /// @notice creates a new token and assigns it to the user submitting the proposal
    /// @param to address of the submitter receiving the token
    /// @param tokenId id of the token to create
    function mint(address to, uint tokenId) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "Token: must have minter role to mint");
        _mint(to,tokenId);
        emit TokenAssigned(to, tokenId);
    }

    /// @notice pauses all token transfers
    function pause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "Token: must have pauser role to pause");
        _pause();
    }

    /// @notice unpauses all token transfers
    function unpause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "Token: must have pauser role to unpause");
        _unpause();
    }

    /// @notice checks authorizations for token transfer
    /// @param from address transferring the token
    /// @param to address receiving the token
    /// @param tokenId id of the transferred token
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Pausable) {
        require(from == address(0) || hasRole(MINTER_ROLE, to), "Token: must be sent to the contract that created it");
        super._beforeTokenTransfer(from, to, tokenId);
    }
}
