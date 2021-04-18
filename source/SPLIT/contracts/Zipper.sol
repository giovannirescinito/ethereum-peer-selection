// SPDX-License-Identifier: MIT

pragma solidity >=0.4.18;
pragma experimental ABIEncoderV2;

/// @title Data zipping functions
/// @author Giovanni Rescinito
/// @notice implements the zipping operations used to compress lists of values in a single data location
library Zipper {    
    /// @notice checks that the width proposed is compatible with the zipping operations
    /// @param width the value to check
    modifier checkWidth(uint width){
        require((width == 4) || (width == 8) || (width == 16) || (width == 32) || (width == 64) || (width == 128),
                 "Width unsupported");
        _;
    }

    /// @notice zips an array of values to a single data location
    /// @param array the array to zip
    /// @param width the number of bits used for each value
    /// @return the zipped version of the array
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

    /// @notice unzips a zipped value to the corresponding array of values
    /// @param zipped the zipped value
    /// @param width the number of bits used for each value
    /// @param size the number of values to extract
    /// @return the array of the unzipped values
    function unzip(uint zipped, uint width, uint size) pure private returns (uint[] memory){
        uint[] memory array = new uint[](size);
        for (uint i=0;i<size;i++){
            array[i] = zipped % (2**width);
            zipped = zipped >> width;
        }
        return array;
    }

    /// @notice zips an array of values using two different widths in an alternate manner 
    /// @param array the values to zip
    /// @param w1 the first width to use
    /// @param w2 the second width to use
    /// @return the zipped version of the array
    function zipDouble(uint[] memory array, uint w1, uint w2) pure private returns (uint){
        uint zipped = 0;
        uint size = array.length;
        if (size == 0){
            return zipped;
        }
        for (uint i=size;i>2;i-=2){
            require(array[i-1] < (2**w2), "Value exceeding 2^w2");
            zipped += array[i-1];
            zipped = zipped << w1;
            require(array[i-2] < (2**w1), "Value exceeding 2^w1");
            zipped += array[i-2];
            zipped = zipped << w2;
        }
        require(array[1] < (2**w2), "Value exceeding 2^w2");
        zipped += array[1];
        zipped = zipped << w1;
        require(array[0] < (2**w1), "Value exceeding 2^w1");
        zipped += array[0];
        return zipped;
    }

    /// @notice unzips a value zipped with two different widths to the corresponding array of values
    /// @param zipped the zipped value
    /// @param w1 the first width to use
    /// @param w2 the second width to use
    /// @param size the number of values to extract
    /// @return the array of the unzipped values
    function unzipDouble(uint zipped, uint w1, uint w2, uint size) pure private returns (uint[] memory){
        uint[] memory array = new uint[](size);
        for (uint i=0;i<size;i+=2){
            array[i] = zipped % (2**w1);
            zipped = zipped >> w1;
            array[i+1] = zipped % (2**w2);
            zipped = zipped >> w2;
        }
        return array;
    }

    /// @notice zips an array of values using two different widths in an alternate manner and includes the size at the end
    /// @param array the values to zip
    /// @return the zipped version of the array
    function zipDoubleArrayWithSize(uint[] memory array) pure public returns (uint){
        uint size = array.length;
        require((size/2)<=(256/32 - 1), "Too many values");
        uint zipped = zipDouble(array,8,24);
        zipped = zipped << 32;
        zipped += size;
        return zipped;
    }

    /// @notice unzips a value, after extracting the size, to the corresponding array of values zipped with two different widths 
    /// @param zipped the zipped value
    /// @return the array of the unzipped values
    function unzipDoubleArrayWithSize(uint zipped) pure public returns (uint[] memory){
        uint size = zipped % (2**32);
        zipped = zipped >> 32;
        return unzipDouble(zipped, 8, 24, size);
    }

    /// @notice zips an array of values using two different widths in an alternate manner, including the size at the end
    /// @param array the values to zip
    /// @param width the number of bits used for each value
    /// @return the zipped version of the array
    function zipArrayWithSize(uint[] memory array, uint width) pure public checkWidth(width) returns (uint){
        uint size = array.length;
        require(size<=(256/width - 1), "Too many values");
        uint zipped = zip(array,width);
        zipped = zipped << width;
        zipped += size;
        return zipped;
    }

    /// @notice unzips a value, after extracting the size, to the corresponding array of values 
    /// @param zipped the zipped value
    /// @param width the number of bits used for each value
    /// @return the array of the unzipped values
    function unzipArrayWithSize(uint zipped, uint width) pure public checkWidth(width) returns (uint[] memory){
        uint size = zipped % (2**width);
        zipped = zipped >> width;
        return unzip(zipped,width,size);
    }

    /// @notice zips an arbitrary length array of values
    /// @param array the values to zip
    /// @param width the number of bits used for each value
    /// @return an array containing all the zipped values required to zip the starting array
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

    /// @notice unzips an array of zipped values
    /// @param array the values to unzip
    /// @param width the number of bits used for each value
    /// @return an array containing all the values obtained after unzipping each of the values of the provided array
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
    
    /// @notice zips a matrix of values, row by row
    /// @param matrix the matrix of values to zip
    /// @param width the number of bits used for each value
    /// @return a zipped matrix, where each row is a zipped array containing all the values of that row zipped
    function zipMatrix(uint[][] memory matrix, uint width) pure public checkWidth(width) returns (uint[][] memory){
        uint rows = matrix.length;
        uint[][] memory zipped = new uint[][](rows);
        for (uint i=0;i<rows;i++){
            zipped[i] = zipArray(matrix[i],width);
        }
        return zipped;
    }

    /// @notice unzips a matrix of values, row by row
    /// @param matrix the matrix of values to unzip
    /// @param width the number of bits used for each value
    /// @return a matrix, where each row contains all the values obtained after unzipping that row
    function unzipMatrix(uint[][] memory matrix, uint width)pure public checkWidth(width) returns (uint[][] memory){
        uint rows = matrix.length;
        uint[][] memory unzipped = new uint[][](rows);
        for (uint i=0;i<rows;i++){
            unzipped[i] = unzipArray(matrix[i],width);
        }
        return unzipped;
    }

    /// @notice zips two array of values using two different widths and combines them into a single array in an alternate manner 
    /// @param a1 the first array to zip
    /// @param a2 the second array to zip
    /// @return the zipped version of the two arrays
    function zipDoubleArray(uint[] memory a1, uint[] memory a2) pure public returns (uint[] memory){
        require(a1.length == a2.length, "Different array sizes");
        uint n = 256/32;
        uint cols = a1.length;
        uint size = cols/n;
        uint last_size = cols%n;
        uint[] memory zipped = new uint[](size+1);
        uint[] memory tmp;
        uint x;
        for (uint j=0;j<size;j++){
            tmp = new uint[](2*n);
            x = 0;
            for (uint k=j*n;k<(j+1)*n;k++){
                tmp[x++] = a1[k];
                tmp[x++] = a2[k];
            }
            zipped[j] = zipDouble(tmp, 8, 24);
        }
        tmp = new uint[](2*last_size);
        x = 0;
        for (uint k=size*n;k<cols;k++){
            tmp[x++] = a1[k];
            tmp[x++] = a2[k];
        }
        zipped[size] = zipDoubleArrayWithSize(tmp);
        return zipped;
    }

    /// @notice unzips an array of values using two different widths in an alternate manner 
    /// @param array the array to unzip
    /// @return the values obtained after unzipping the array
    function unzipDoubleArray(uint[] memory array)pure public returns (uint[] memory){
        uint size = array.length;
        if (size == 0){
            return new uint[](0);
        }
        uint n = 256/32*2;
        uint index;
        uint[] memory last = unzipDoubleArrayWithSize(array[size-1]);
        uint[] memory unzipped = new uint[](n*(size-1) + last.length);
        for (uint i=0;i<size-1;i++){
            uint[] memory tmp = unzipDouble(array[i],8,24,n);
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

    /// @notice unzips a matrix of values using two different widths in an alternate manner 
    /// @param matrix the matrix to unzip
    /// @return the unzipped matrix, where each row is the unzipped version of the corresponding row, obtained after unzipping using two different widths
    function unzipDoubleMatrix(uint[][] memory matrix)pure private  returns (uint[][] memory){
        uint rows = matrix.length;
        uint[][] memory unzipped = new uint[][](rows);
        for (uint i=0;i<rows;i++){
            unzipped[i] = unzipDoubleArray(matrix[i]);
        }
        return unzipped;
    }

    /// @notice unzips the zipped score matrix and reconstructs the nxn starting matrix
    /// @param scoreMat the zipped score matrix
    /// @return the unzipped nxn score matrix
    function reconstructScoreMatrix(uint[][] memory scoreMat) pure public returns (uint[][] memory){
        uint[][] memory scores = unzipDoubleMatrix(scoreMat);
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