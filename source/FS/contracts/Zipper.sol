// SPDX-License-Identifier: UNLICENSED


pragma solidity >=0.4.18;
pragma experimental ABIEncoderV2;

library Zipper {    
    modifier checkWidth(uint width){
        require((width == 4) || (width == 8) || (width == 16) || (width == 32) || (width == 64) || (width == 128),
                 "Width unsupported");
        _;
    }

    function zip(uint[] memory array, uint width) pure private returns (uint){
        uint zipped = 0;
        uint size = array.length;
        if (size == 0){
            return zipped;
        }
        for (uint i=size;i>1;i--){
            require(array[i-1] < (2**width), "Value exceeding 2^width");
            zipped += array[i-1];
            zipped = zipped << width;
        }
        require(array[0] < (2**width), "Value exceeding 2^width");
        zipped += array[0];
        return zipped;
    }

    function unzip(uint zipped, uint width, uint size) pure private returns (uint[] memory){
        uint[] memory array = new uint[](size);
        for (uint i=0;i<size;i++){
            array[i] = zipped % (2**width);
            zipped = zipped >> width;
        }
        return array;
    }

    function zipArrayWithSize(uint[] memory array, uint width) pure public checkWidth(width) returns (uint){
        uint size = array.length;
        require(size<=(256/width - 1), "Too many values");
        uint zipped = zip(array,width);
        zipped = zipped << width;
        zipped += size;
        return zipped;
    }

    function unzipArrayWithSize(uint zipped, uint width) pure public checkWidth(width) returns (uint[] memory){
        uint size = zipped % (2**width);
        zipped = zipped >> width;
        return unzip(zipped,width,size);
    }

    function zipArray(uint[] memory array, uint width) pure public checkWidth(width) returns (uint[] memory){
        uint n = 256/width;
        uint cols = array.length;
        uint size = cols/n;
        uint last_size = cols%n;
        uint[] memory zipped = new uint[](size+1);
        uint[] memory tmp;
        uint x;
        for (uint j=0;j<size;j++){
            tmp = new uint[](n);
            x = 0;
            for (uint k=j*n;k<(j+1)*n;k++){
                tmp[x] = array[k];
                x++;
            }
            zipped[j] = zip(tmp,width);
        }
        tmp = new uint[](last_size);
        x = 0;
        for (uint k=size*n;k<cols;k++){
            tmp[x] = array[k];
            x++;
        }
        zipped[size] = zipArrayWithSize(tmp,width);
        return zipped;
    }

    function unzipArray(uint[] memory array, uint width)pure public checkWidth(width) returns (uint[] memory){
        uint size = array.length;
        if (size == 0){
            return new uint[](0);
        }
        uint n = 256/width;
        uint index;
        uint[] memory last = unzipArrayWithSize(array[size-1],width);
        uint[] memory unzipped = new uint[](n*(size-1) + last.length);
        for (uint i=0;i<size-1;i++){
            uint[] memory tmp = unzip(array[i],width,n);
            index = i*n;
            for (uint j=0;j<n;j++){
                unzipped[index] = tmp[j];
                index++;
            }
        }
        index = n*(size-1);
        for (uint i=0;i<last.length;i++){
            unzipped[index] = last[i];
            index++;
        }
        return unzipped;
    }
    
    function zipMatrix(uint[][] memory matrix, uint width) pure public checkWidth(width) returns (uint[][] memory){
        uint rows = matrix.length;
        uint[][] memory zipped = new uint[][](rows);
        for (uint i=0;i<rows;i++){
            zipped[i] = zipArray(matrix[i],width);
        }
        return zipped;
    }

    function unzipMatrix(uint[][] memory matrix, uint width)pure public checkWidth(width) returns (uint[][] memory){
        uint rows = matrix.length;
        uint[][] memory unzipped = new uint[][](rows);
        for (uint i=0;i<rows;i++){
            unzipped[i] = unzipArray(matrix[i],width);
        }
        return unzipped;
    }

    function reconstructScoreMatrix(uint[][] memory scoreMat) pure public returns (uint[][] memory){
        uint[][] memory scores = unzipMatrix(scoreMat,16);
        uint n = scores.length;
        uint[][] memory scoreMatrix = new uint[][](n);
        for (uint i=0;i<n;i++){
            scoreMatrix[i] = new uint[](n);
            uint len = scores[i].length;
            for (uint j=0;j<len;j+=2){
                scoreMatrix[i][scores[i][j]] = scores[i][j+1];
            }
        }
        return scoreMatrix;
    }   
}