async function main() {
    const { ethers, upgrades } = require("hardhat");

    const proxyAddress = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"; // 替换为实际的代理合约地址

    const MyContractV2 = await ethers.getContractFactory("MyContractV2");
    console.log("Upgrading to MyContractV2...");
    const upgraded = await upgrades.upgradeProxy(proxyAddress, MyContractV2);
    console.log("MyContractV2 deployed to:", upgraded.address);
}

main()
    .then(() => {
        console.log("Upgrade completed.");
        process.exit(0);
    })
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
