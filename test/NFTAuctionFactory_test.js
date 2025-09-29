const { expect } = require("chai");
const {ethers,deployments,upgrades} =require("hardhat");

describe("NFTAuctionFactory_test", function () {
  let admin,seller,buyer1,buyer2;
  let factory,auctionProy,auctionProxyAddress,auction,implAddress1;
  let nft,nftAddress,erc20,erc20Address;
  let priceUSD = 10, nftTokenId = 1;
  before(async function () {
    //获取合约部署者和其他用户
    [admin,seller,buyer1,buyer2] = await ethers.getSigners();
    //1、部署NFTAuction合约
    await deployments.fixture(["deployNftAuction"]);
    console.log(`admin: ${admin.address}`);
    auctionProy = await deployments.get("NftAuctionProxy");
    auctionProxyAddress = await auctionProy.address;
    auction = await ethers.getContractAt("NFTAuction", auctionProxyAddress);
    implAddress1 = await upgrades.erc1967.getImplementationAddress(auctionProxyAddress);
    //2、部署NFTAuctionFactory工厂合约
    const auctionFactory = await ethers.getContractFactory("NFTAuctionFactory");
    const factoryProxy = await upgrades.deployProxy(auctionFactory,[implAddress1], {
        initializer: "initialize"
    });
    await factoryProxy.waitForDeployment();
    //3、创建NFTAuctionFactory合约实例
    factory = await ethers.getContractAt("NFTAuctionFactory", await factoryProxy.getAddress());
    //4、部署NFT合约，并创建NFT拍卖品
    const nftFactory = await ethers.getContractFactory("MyERC721");
    nft = await nftFactory.deploy("NFT","NFT");
    await nft.waitForDeployment();
    nftAddress = await nft.getAddress();
  });
  it("upgrades before createAuction", async () => {
    await nft.mintNFT(seller,"tokenUri_" + nftTokenId);
    await factory.createAuction(seller, nftAddress, nftTokenId, priceUSD, 10);
    const auctionCount1 = await factory.getAuctionCount();
    console.log(`拍卖品数量: ${auctionCount1}`);
    expect(auctionCount1).to.equal(1);
    auctionV1Address = await factory.getAuctionAddress(nftTokenId);
    console.log(`拍卖品1地址: ${auctionV1Address}`);
    console.log(`implAddress1: ${implAddress1}`);
  //});
  //if("upgrades after createAuction", async () => {
    //5、升级拍卖品合约
    await deployments.fixture(["upgradeNftAuction"]);
    const implAddress2 = await upgrades.erc1967.getImplementationAddress(auctionProxyAddress);
    console.log(`implAddress2: ${implAddress2}`);
    
    await factory.setAuctionImplementation(implAddress2);  //升级后续新创建的拍卖品合约
    // //通过信标代理地址升级已创建的拍卖品合约
    // beaconAddress = await factory.getBeaconAddress();
    // beacon = await ethers.getContractAt("UpgradeableBeacon", beaconAddress);
    // console.log(`beaconAddress: ${beaconAddress}`,beacon);
    // await beacon.upgradesTo(implAddress2);
    nftTokenId++;
    await nft.mintNFT(seller,"tokenUri_" + nftTokenId);
    await factory.createAuction(seller, nftAddress, nftTokenId, priceUSD, 10);
    const auctionCount2 = await factory.getAuctionCount();
    console.log(`拍卖品数量: ${auctionCount2}`);
    expect(auctionCount2).to.equal(2);

    // 验证升级前创建拍卖品合约版本
    auctionV1Address = await factory.getAuctionAddress(1);
    console.log(`拍卖品1地址: ${auctionV1Address}`);
    auction1 = await ethers.getContractAt("NFTAuctionV2", auctionV1Address);
    const auctionV1Version =  await auction1.getVersion();
    expect(auctionV1Version).to.equal("NFTAuctionV2");  

    //6、验证升级后的拍卖品合约版本
    const auctionV2Address = await factory.getAuctionAddress(2);
    console.log(`拍卖品2地址: ${auctionV2Address}`);
    auction2 = await ethers.getContractAt("NFTAuctionV2", auctionV2Address);
    const auctionV2Version =  await auction2.getVersion();
    expect(auctionV2Version).to.equal("NFTAuctionV2");  

  });
});