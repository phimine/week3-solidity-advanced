async function main() {
    const { ethers, upgrades } = require("hardhat");

    const MyContractV1 = await ethers.getContractFactory("MyContractV1");
    console.log("Deploying MyContractV1...");
    const instance = await upgrades.deployProxy(MyContractV1, [42], {
        initializer: "initialize",
    });
    await instance.waitForDeployment();
    console.log("MyContractV1 deployed to:", instance.target);

    // 保存代理合约地址
    const proxyAddress = instance.target;
    console.log("Proxy deployed to:", proxyAddress);

    return proxyAddress;
}

main()
    .then((proxyAddress) => {
        console.log("Deployment completed. Proxy address:", proxyAddress);
        process.exit(0);
    })
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
