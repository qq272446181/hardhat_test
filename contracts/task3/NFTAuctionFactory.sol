// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NFTAuction.sol";
import "./interfaces/INftAuction.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "hardhat/console.sol";

contract NFTAuctionFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // 管理员（与 Owner 可区分，只有 owner 能升级/换实现）
    address public admin;
    address[] public auctions;
    address public auctionImplementation;
    // 当前使用的逻辑实现地址（用于后续新建）
    UpgradeableBeacon public beacon;

    mapping(uint256 => address) public auctionMap;

    event AuctionCreated(uint256 indexed tokenId, address nftAddress, address indexed seller, uint256 startPriceUSD, uint256 duration);
    event AuctionImplementationUpdated(address indexed oldImpl, address indexed newImpl);

    function initialize(address _auctionImplementation) initializer public {
        require(_auctionImplementation != address(0), "Invalid implementation address");

        __Ownable_init();
        __UUPSUpgradeable_init();
        admin = msg.sender;
        auctionImplementation = _auctionImplementation;
        beacon = new UpgradeableBeacon(_auctionImplementation,address(this));
    }

    function createAuction(
        address _seller,
        address _nftContract,
        uint256 _tokenId,
        uint256 _startPriceUSD,
        uint256 _duration
    ) external {
        require(_seller != address(0), "Seller cannot be zero address");
        require(_nftContract != address(0), "NFT contract address cannot be zero address");
        require(_duration > 0, "Duration must be greater than zero");

        // 使用信标创建新的代理实例
        address implementation = beacon.implementation();
        bytes memory data = abi.encodeWithSelector(
            INftAuction(implementation).createAuction.selector, 
            _seller, 
            _nftContract, 
            _tokenId, 
            _startPriceUSD, 
            _duration
        );
        address auctionAddress = address(new BeaconProxy(address(beacon), data));

        auctionMap[_tokenId] = auctionAddress;
        auctions.push(auctionAddress);

        emit AuctionCreated(_tokenId, _nftContract, _seller, _startPriceUSD, _duration);
    }

    function getAuctionCount() external view returns (uint256) {
        return auctions.length;
    }

    function getAuctionAddress(uint256 _tokenId) external view returns (address) {
        address auctionAddress = auctionMap[_tokenId];
        require(auctionAddress != address(0), "Auction not found");
        return auctionAddress;
    }

    function setAuctionImplementation(address _newImplementation) external onlyOwner {
        require(_newImplementation != address(0), "Invalid implementation address");
        require(_newImplementation != address(beacon.implementation()), "Same implementation address");
 
        address oldImplementation = address(beacon.implementation());       
        auctionImplementation = _newImplementation;
        beacon.upgradeTo(_newImplementation);
        emit AuctionImplementationUpdated(oldImplementation, _newImplementation);
    }
    function getBeaconAddress() external view returns (address) {
        return address(beacon);
    }

    // UUPS 升级授权
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        require(newImplementation != address(0), "Invalid implementation address");
    }

    function getAuctionVersion(uint256 _tokenId) external view returns (string memory) {
        address auctionAddress = auctionMap[_tokenId];
        require(auctionAddress != address(0), "Auction not found");

        NFTAuction auction = NFTAuction(auctionAddress);
        return auction.getVersion();
    }

    receive() external payable {}
}
