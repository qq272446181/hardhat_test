const {ethers, upgrades} = require("hardhat");
const fs = require("fs");
const path = require("path");

module.exports = async function({getNamedAccounts, deployments}){
    const {save} = deployments;
    const { owner } = await getNamedAccounts();
    console.log("升级用户地址:", owner);

    //获取部署的合约信息
    const storePath =path.resolve(__dirname,"./.cache/nft_auction_store.json");
    const store = JSON.parse(fs.readFileSync(storePath, "utf-8"));
    //console.log(`升级前代理合约 address：${store.proxyAddress}`);

    //获取升级后的合约V2
    const nftAuctionV2 = await ethers.getContractFactory("NFTAuctionV2");
    //升级合约
    const nftAuctionPorxyV2 = await upgrades.upgradeProxy(
        store.proxyAddress, 
        nftAuctionV2,
        {call:"admin"}
    );
    await nftAuctionPorxyV2.waitForDeployment();
    
    const proxyV2Address = await nftAuctionPorxyV2.getAddress();
    //console.log(`升级后代理合约V2 address: ${proxyV2Address}`);
    const implAddress = await upgrades.erc1967.getImplementationAddress(proxyV2Address);
    //console.log(`升级后逻辑合约V2 address: ${implAddress}`);

    //保存部署信息
    save("NftAuctionPorxyV2", {
        address: proxyV2Address,
        abi: nftAuctionPorxyV2.abi,
    });
};

module.exports.tags = ["upgradeNftAuction"];