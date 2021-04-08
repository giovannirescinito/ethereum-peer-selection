// SPDX-License-Identifier: UNLICENSED


pragma solidity >=0.4.18;
pragma experimental ABIEncoderV2;

import "contracts/Zipper.sol";

library Allocations {
    //Data Structures
    struct Allocation {
        uint232 shares;
        uint24 p;
    }

    struct Map {
        Allocation[] elements;
        mapping (bytes32 => uint) idx;
    }

    //Setters
    function setAllocation(Map storage map, uint[] calldata a, uint p) external {
        bytes32 h = keccak256(abi.encodePacked(a));
        uint index = map.idx[h];
        if (index == 0) {
            map.elements.push(Allocation(uint232(Zipper.zipArrayWithSize(a,8)), uint24(p)));
            map.idx[h] = map.elements.length;
        }else {
            map.elements[index - 1].p = uint24(p);
        }
    }

    function updateShares(Map storage map, uint index, uint[] calldata shares) external {
        require(index >= 0 && index < map.elements.length, "Map out of bounds"); 
        map.elements[index].shares = uint232(Zipper.zipArrayWithSize(shares,8));
    }

    //Getters
    function length(Map storage map) view external returns (uint){
        return map.elements.length;
    }

    function getAllocations(Map storage map) view external returns (uint[][] memory, uint[] memory) {
        uint n = map.elements.length;
        uint[][] memory allocations = new uint[][](n);
        uint[] memory p = new uint[](n);
        for (uint i=0;i<n;i++){
            allocations[i] = getShares(map.elements[i]);
            p[i] = map.elements[i].p;
        }
        return (allocations,p);
    }

    function getP(Allocation calldata a) pure external returns (uint) {
        return a.p;
    }

    function getShares(Allocation memory a) pure public returns (uint[] memory) {
        return Zipper.unzipArrayWithSize(a.shares,8);
    }

    function getAllocationAt(Map storage map, uint index) view external returns (Allocation memory) {
        require(index >= 0 && index < map.elements.length, "Map out of bounds"); 
        return map.elements[index];
    }
}
