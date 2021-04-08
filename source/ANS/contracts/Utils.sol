// SPDX-License-Identifier: UNLICENSED

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

    //Math functions
    function ceil(uint x) pure public returns (uint){
        return ((x + C - 1) / C) * C;
    }

    function floor(uint x) pure public returns (uint){
        return (x/C)*C;
    }

    function round(uint x) pure public returns (uint){
        if (x-floor(x) < C/2){
            return floor(x);
        }else{
            return ceil(x);
        }
    }

    function range(uint upper) pure external returns (uint[] memory) {
        uint[] memory a = new uint[](upper);
        for (uint i=0;i<upper;i++){
            a[i] = i;
        }
        return a;
    }
    
    //Sorting functions

    // https://gist.github.com/subhodi/b3b86cc13ad2636420963e692a4d896f

    function sort(uint[] calldata data) pure external returns(Element[] memory) {
        Element[] memory dataElements = new Element[](data.length);
        for (uint i=0; i<data.length; i++){
            dataElements[i] = Element(i,data[i]);
        }
       quickSort(dataElements, int(0), int(dataElements.length - 1));
       return dataElements;
    }
    
    function quickSort(Element[] memory arr, int left, int right) pure internal{
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