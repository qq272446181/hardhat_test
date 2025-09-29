const { deployments,upgrades, ethers } = require("hardhat");
const fs = require("fs");
const path =require("path");

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { save } = deployments;
    const { owner } = await getNamedAccounts();
    //console.log("部署用户地址:", owner);
    const nftAuction = await ethers.getContractFactory("NFTAuction");
    const nftAuctionProxy = await upgrades.deployProxy(nftAuction,[], {
        initializer: "initialize"
    });
    await nftAuctionProxy.waitForDeployment();
    const proxyAddress = await nftAuctionProxy.getAddress();
    const implAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);

    //console.log("代理合约 address:", proxyAddress);
    //console.log("实现逻辑合约 address:",implAddress);

    const storePath =path.resolve(__dirname,"./.cache/nft_auction_store.json");

    fs.writeFileSync(storePath,JSON.stringify({
        proxyAddress,
        implAddress,
        abi:nftAuction.interface.format("json"),
    }));
    await save("NftAuctionProxy", {
        abi: nftAuction.interface.format("json"),
        address: proxyAddress,
    });
};

module.exports.tags = ["deployNftAuction"];