// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NFTAuction.sol";
contract NFTAuctionV2 is NFTAuction {
    // NFT contract address
    function getVersion() public override pure returns (string memory) {
        return "NFTAuctionV2";
    }
}