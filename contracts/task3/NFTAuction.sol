// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/INftAuction.sol";
import "./test/AggreagatorV3.sol";
import "hardhat/console.sol";

contract NFTAuction is INftAuction,IERC721Receiver, Initializable, UUPSUpgradeable {

    //管理员地址
    address public admin;
    //下一个拍卖品ID
    uint256 internal nextAuctionId;
    //拍卖品信息集合
    mapping(uint256 => AuctionInfo) public auctions;
    // ETC20/USD 价格预言机
    mapping(address => AggregatorV3Interface) public priceFeeds;
    //支持代币列表
    mapping(address => bool) private supportedTokens;
    mapping(uint256 tokenId => address nftAddress) private tokeIdToNftAddress;

    function initialize() public initializer{
        admin = msg.sender;
        nextAuctionId = 0;
        console.log("NFTAuction admin:",admin);
        //setPriceFeedUSD(address(0), 0x694AA1769357215DE4FAC081bf1f309aDC325306);
        //setPriceFeedUSD(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238, 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E);
    }
    // 必须实现这个函数来安全接收NFT
    function onERC721Received(
        address operator,
        address from,
        uint256 _tokenId,
        bytes calldata
    ) external view override returns (bytes4) {
        // 验证NFT来自预期的合约
        require(msg.sender == tokeIdToNftAddress[_tokenId], "Unexpected NFT contract");

        // 必须返回这个魔法值
        return this.onERC721Received.selector;
    }
    function setPriceFeedUSD(address _tokenAddress, address _priceFeed) public {
        priceFeeds[_tokenAddress] = AggregatorV3Interface(_priceFeed);
        if(_tokenAddress!= address(0)){
            supportedTokens[_tokenAddress] = true;
        }
    }
    //创建拍卖品
    function createAuction(
        address _seller,
        address _nftContract,
        uint256 _tokenId,
        uint256 _startPriceUSD,
        uint256 _duration
    ) public{
        require(_seller!= address(0), "Seller address cannot be zero");
        require(_nftContract!= address(0), "NFT contract address cannot be zero");
        require(_tokenId > 0, "Token ID must be greater than zero");
        require(_startPriceUSD > 0, "Starting priceUSD must be greater than zero");
        require(_duration > 5, "Duration must be greater than 5s");
        auctions[nextAuctionId] = AuctionInfo({
            seller: _seller,
            nftContract: _nftContract,
            tokenId: _tokenId,
            startPriceUSD: _startPriceUSD,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            paymentToken: address(0),
            highestBidder: address(0),
            highestBid: 0,
            highestBidUSD: 0,
            ended: false
        });
        tokeIdToNftAddress[_tokenId] = _nftContract;
        // 转移 NFT 到合约
        IERC721(_nftContract).safeTransferFrom(_seller, address(this), _tokenId);
        emit AuctionCreated(nextAuctionId, _seller, _nftContract, _tokenId, _startPriceUSD, _duration);
        nextAuctionId++;
    }
    function getPriceFeedAmount(address _tokenAddress, uint256 _amount) public view returns(uint256){
        AggregatorV3Interface priceFeed = priceFeeds[_tokenAddress];
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint256 priceFeeedAmount = uint256(price) * _amount;
        return priceFeeedAmount;
    }
     // 设置价格Feed
    function bid(uint256 auctionId, uint256 _bidAmount,address paymentToken) external payable {
        AuctionInfo storage auction = auctions[auctionId];
        require(auction.seller!= address(0), "Auction does not exist");
        require(auction.ended == false || block.timestamp < auction.endTime, "Auction has ended");
        require(msg.sender != auction.seller, "Seller cannot bid");
        uint amountUSD;
        if(paymentToken != address(0)){
            //erc20换算成USD
            require(supportedTokens[paymentToken],"ERC20 Price feed not set");
            amountUSD = getPriceFeedAmount(paymentToken, _bidAmount);
        }else{
            _bidAmount = msg.value;
            amountUSD = getPriceFeedAmount(address(0), _bidAmount);
        }
        require(amountUSD > auction.startPriceUSD, "Auction: Bid must be higher than starting price");
        require(amountUSD > auction.highestBidUSD, "Auction: Bid must be higher than current bid");
        // 退还前一个最高出价者的资金
        if (auction.highestBidder != address(0)) {
            _refundPreviousBidder(auctionId);
        } 
        //接受当前出价ERC20币种
        if (paymentToken != address(0)) {
            IERC20(paymentToken).transferFrom(msg.sender, address(this), _bidAmount);
        }
        
        auction.highestBidder = msg.sender;
        auction.highestBid = _bidAmount;
        auction.highestBidUSD = amountUSD;
        auction.paymentToken = paymentToken;
        emit NewHighestBid(msg.sender, auction.highestBidUSD,paymentToken);
    }
    // 退还前一个最高出价者的资金
    function _refundPreviousBidder(uint256 auctionId) internal { 
        AuctionInfo storage auction = auctions[auctionId];
        if (auction.paymentToken == address(0)) {
            // 退回ETH
            payable(auction.highestBidder).transfer(auction.highestBid);
        } else {
            // 退回ERC20
            IERC20(auction.paymentToken).transfer(auction.highestBidder, auction.highestBid);
        }
    }
    
    function endAuction(uint256 auctionId) external {
        AuctionInfo storage auction = auctions[auctionId];
        require(block.timestamp >= auction.endTime, "Auction has not ended yet");
        require(!auction.ended, "Auction has already ended");
        auction.ended = true;
        if (auction.highestBidder != address(0)) {
            // 转移 NFT 给获胜者
            IERC721(auction.nftContract).transferFrom(address(this), auction.highestBidder, auction.tokenId);
            // 转移资金给卖家
            if (auction.paymentToken == address(0)) {
                payable(auction.seller).transfer(auction.highestBid);
            } else {
                IERC20(auction.paymentToken).transfer(auction.seller, auction.highestBid);
            }
            emit AuctionEnded(auction.highestBidder, auction.highestBidUSD, auction.paymentToken);
        } else {
            // 如果没有出价，退回 NFT
            IERC721(auction.nftContract).transferFrom(address(this), auction.seller, auction.tokenId);
            emit AuctionEnded(address(0), 0, address(0));
        }
    }
    function getAuction(uint256 auctionId) public view returns 
    (
        AuctionInfo memory
    ) 
    {
        return auctions[auctionId];
    }
    function getNextAuctionId() public view returns(uint256){
        return nextAuctionId;
    }
    
    function _authorizeUpgrade(address) internal view override {
        require(msg.sender == admin, "Only admin can upgrade");
    }
    function getVersion() public virtual pure returns (string memory) {
        return "NFTAuctionV1";
    }
}