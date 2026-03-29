const hre = require("hardhat");
async function main() {
  const [deployer] = await ethers.getSigners();
  const Vault = await ethers.getContractFactory("FlowGuardXPrime");
  const vault = await Vault.deploy([deployer.address], [deployer.address], 1);
  await vault.deployed();
  console.log("FlowGuard X Prime Deployed to:", vault.address);
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
