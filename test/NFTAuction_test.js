const { expect } = require("chai");
const {ethers,deployments,upgrades} =require("hardhat");

describe("NFTAuction_test", function () {
  it("Should be ok", async function () {
    //获取合约部署者和其他用户
    const [owner,seller,buyer1,buyer2] = await ethers.getSigners();

    //1、部署NFTAuction的代理合约和逻辑合约
    await deployments.fixture(["deployNftAuction"]);
    const nftProxy = await deployments.get("NftAuctionProxy");
    const autctionProxyAddress = await nftProxy.address;
    console.log(`autctionProxyAddress : ${autctionProxyAddress}`);
    const nftAuction = await ethers.getContractAt("NFTAuction", autctionProxyAddress);
    //部署NFT合约
    const NFT = await ethers.getContractFactory("MyERC721");
    const nft = await NFT.deploy("NFT","NFT");
    await nft.waitForDeployment();
    const nftTokenId = await nft.mintNFT(seller,"tokenUri");
    const nftAddress = await nft.getAddress();
    console.log(`nftAddress: ${nftAddress} seller: ${seller.address} nftTokenId: ${nftTokenId}`);
    //2、创建一个拍卖品
    await nftAuction.createAuction(seller.address,nftAddress,1,1,10);
    const auctionbefore = await nftAuction.getAuction(0);
    //console.log("auction upgrade before:",auctionbefore);
    const implAddress1 = await upgrades.erc1967.getImplementationAddress(nftProxy.address);
    console.log(`implAddress1: ${implAddress1}`);

    //3、升级合约
    await deployments.fixture(["upgradeNftAuction"]);
    const implAddress2 = await upgrades.erc1967.getImplementationAddress(nftProxy.address);
    console.log(`implAddress2: ${implAddress2}`);
    // //4、获取第一个拍卖品信息
    const nftAuctionV2 = await ethers.getContractAt("NFTAuctionV2", nftProxy.address);
    const auctionAfter = await nftAuctionV2.getAuction(0);
    //console.log(`auction upgrade after:`,auctionAfter);
    const version = await nftAuctionV2.getVersion();
    console.log(`version: ${version}`);
    //断言：拍卖品信息不变，合约地址变化
    expect(auctionbefore.startTime).to.equal(auctionAfter.startTime);
    expect(implAddress1).to.not.equal(implAddress2);
    
    //获取ERC20代币合约
    const ERC20 = await ethers.getContractFactory("MyERC20");
    const erc20 = await ERC20.deploy();
    await erc20.waitForDeployment();
    await erc20.transfer(buyer1,1000);
    console.log(`autctionProxyAddress: ${autctionProxyAddress}`);
    await erc20.connect(buyer1).approve(autctionProxyAddress,1000);
    //console.log(`allowance:buyer1 ${buyer1};授权地址：${nftAuctionV2}`);
    await erc20.transfer(buyer2,1000);
    await erc20.connect(buyer2).approve(autctionProxyAddress,1000);
    const balance1 = await erc20.balanceOf(buyer1);
    const buyer1Address = await buyer1.getAddress();
    console.log(`buyer1=${buyer1Address} balance: ${balance1}`);
    const erc20Address = await erc20.getAddress();
    //console.log(`erc20Address: ${erc20Address}`);
    //部署ERC20预言机
    const PriceFeed = await ethers.getContractFactory("AggreagatorV3");
    const priceFeed = await PriceFeed.deploy(1000);
    await priceFeed.waitForDeployment();
    const priceAddressUSD = await priceFeed.getAddress();
    //设置价格源
    await nftAuctionV2.setPriceFeedUSD(erc20Address,priceAddressUSD);
    //ETH预言机
    const ETHAggreagatorV3 = await ethers.getContractFactory("ETHAggreagatorV3");
    const ethFeed = await ETHAggreagatorV3.deploy();
    await ethFeed.waitForDeployment();
    const ethFeedAddressUSD = await ethFeed.getAddress();
    //设置ETH价格源
    await nftAuctionV2.setPriceFeedUSD(ethers.ZeroAddress,ethFeedAddressUSD);
    //console.log(`priceAddressUSD: ${priceAddressUSD}`);
    //5、买家参与拍卖
    await nftAuctionV2.connect(buyer1).bid(0, 10,erc20Address);
    await nftAuctionV2.connect(buyer2).bid(0, 0,ethers.ZeroAddress,{ value: 10 });
    await nftAuctionV2.connect(buyer1).bid(0, 21,erc20Address);
    //6、拍卖结束，获取NFT
    await new Promise((resolve) => setTimeout(resolve, 11 * 1000));
    await nftAuctionV2.endAuction(0);
    const aution = await nftAuction.getAuction(0);
    console.log(`拍卖状态: ${aution.ended}; 获得NFT的用户: ${aution.highestBidder};最高价：${aution.highestBid}（${aution.highestBidUSD} USD）`);
  
    expect(aution.ended).to.be.true;
    expect(aution.highestBidder).to.equal(buyer1.address);
    const nftOwner = await nft.ownerOf(1);
    console.log(`NFT owner: ${nftOwner}`);
    expect(nftOwner).to.equal(aution.highestBidder);
    BidderBalance = await erc20.balanceOf(owner.address);
    console.log(`拍卖品买家余额: ${BidderBalance}`);
  });
});