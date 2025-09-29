// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

interface INftAuction {
    //拍卖结构体
    struct AuctionInfo{
        //卖家
        address seller;
        //NFT合约地址
        address nftContract;
        //NFT代币ID
        uint256 tokenId;
        //起始价格
        uint256 startPriceUSD;
        //开始时间
        uint256 startTime;
        //结束时间
        uint256 endTime;
        //支付币种
        address paymentToken;
        //当前最高出价者
        address highestBidder;
        //当前最高出价
        uint256 highestBid;
        //当前最高出价的USD值
        uint256 highestBidUSD;
        //是否结束
        bool ended;
    }
    event AuctionCreated(uint256 auctionId,address _seller,address _nftContract,uint256 _tokenId,uint256 _startPriceUSD,uint256 _duration);
    event NewHighestBid(address bidder, uint256 amountUSD,address paymentToken);
    event AuctionEnded(address winner, uint256 amountUSD,address paymentToken);
    function initialize() external;
    function setPriceFeedUSD(address _tokenAddress, address _priceFeed) external;
    //创建拍卖品
    function createAuction(
        address _seller,
        address _nftContract,
        uint256 _tokenId,
        uint256 _startPriceUSD,
        uint256 _duration
    ) external;
    function getPriceFeedAmount(address _tokenAddress, uint256 _amount) external view returns(uint256);
     // 设置价格Feed
    function bid(uint256 auctionId, uint256 _bidAmount,address paymentToken) external payable;
    
    function endAuction(uint256 auctionId) external;
    function getAuction(uint256 auctionId) external view returns (AuctionInfo memory);
    function getNextAuctionId() external view returns(uint256);
    
    function getVersion() external pure returns (string memory);
}