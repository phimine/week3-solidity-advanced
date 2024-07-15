require("@openzeppelin/hardhat-upgrades");
const { ethers, upgrades } = require("hardhat");

async function main() {
    const CrowdfundingPlatform = await ethers.getContractFactory(
        "CrowdfundingPlatform",
    );
    const platform = await upgrades.deployProxy(
        CrowdfundingPlatform,
        ["0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199"],
        {
            initializer: "initialize",
        },
    );

    await platform.waitForDeployment();
    console.log(
        "CrowdfundingPlatform deployed to:",
        CrowdfundingPlatform.target,
    );
    console.log("CrowdfundingPlatform deployed to:", platform.target);
    console.log("Proxy deployed to:", platform.target);
}

main()
    .then(() => {
        console.log("V1 Deploy completed!");
        process.exit(0);
    })
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
