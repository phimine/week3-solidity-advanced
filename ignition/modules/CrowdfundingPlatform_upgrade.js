const { ethers, upgrades } = require("hardhat");

async function main() {
    const proxyAddress = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"; // 替换为实际的代理合约地址

    const CrowdfundingPlatformV2 = await ethers.getContractFactory(
        "CrowdfundingPlatformV2",
    );
    console.log("Upgrading to V2...");
    const upgraded = await upgrades.upgradeProxy(
        proxyAddress,
        CrowdfundingPlatformV2,
    );
    console.log("V2 deployed to:", upgraded.address);
}

main()
    .then(() => {
        console.log("============completed!");
        process.exit(0);
    })
    .catch((error) => {
        console.log(error);
        process.exit(1);
    });
