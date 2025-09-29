// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ReverseStr{
    function reverse(string memory str) public pure returns (string memory) {
        bytes memory bytesStr = bytes(str);
        bytes memory revbytes = new bytes(bytesStr.length); // Allocate memory for the reversed string
        uint256 len = bytesStr.length;
        for(uint256 i = 0; i<len/2; i++) {
            revbytes[i] = bytesStr[len - i - 1]; // Reverse the string by swapping characters
            revbytes[len - i - 1] = bytesStr[i];
        }
        return string(revbytes);
    }
}