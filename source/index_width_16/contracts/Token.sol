// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "contracts/ImpartialSelectionInterface.sol";

contract Token is Context, AccessControl, ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdTracker;

    mapping(uint => address) private tokenMinter;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    event TokenAssigned(address to, uint tokenId);
    
    constructor(string memory name, string memory symbol, string memory baseURI) public ERC721(name, symbol) {
        _setBaseURI(baseURI);
    }

    function addMinter() external {
        require(ImpartialSelectionInterface(_msgSender()).isImpartialSelection(), "Sender is not using PET");
        _setupRole(MINTER_ROLE, _msgSender());
    }

    function mint(address to) public virtual returns (uint) {
        require(hasRole(MINTER_ROLE, _msgSender()), "Token: must have minter role to mint");
        uint tokenId = _tokenIdTracker.current();
        _mint(to,tokenId);
        _tokenIdTracker.increment();
        tokenMinter[tokenId] = _msgSender();
        emit TokenAssigned(to, tokenId);
        return tokenId;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721) {
        require(from == address(0) || (hasRole(MINTER_ROLE, to) && tokenMinter[tokenId] == to), "Token: must be sent to the contract that created it");
        super._beforeTokenTransfer(from, to, tokenId);
    }
}
