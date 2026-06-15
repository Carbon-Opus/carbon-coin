import { ethers, deployments } from "hardhat";
import { expect } from "chai";
import { CarbonCoin, CarbonCoinLauncher, CarbonCoinConfig } from "../typechain-types";

describe("CarbonCoin", () => {
  let carbonCoin: CarbonCoin;
  let carbonCoinLauncher: CarbonCoinLauncher;
  let carbonCoinConfig: CarbonCoinConfig;
  let deployer: any;

  beforeEach(async () => {
    await deployments.fixture(["CarbonCoinLauncher"]);
    const namedAccounts = await ethers.getNamedSigners();
    deployer = namedAccounts.deployer;

    carbonCoinConfig = await ethers.getContract<CarbonCoinConfig>("CarbonCoinConfig");
    carbonCoinLauncher = await ethers.getContract<CarbonCoinLauncher>("CarbonCoinLauncher");

    const bondingCurveParams = {
      virtualUsdc: ethers.utils.parseUnits("5000", 6),
      virtualTokens: ethers.utils.parseEther("6000000"),
      creatorReserve: ethers.utils.parseEther("1000000"),
      liquiditySupply: ethers.utils.parseEther("4500000"),
      curveSupply: ethers.utils.parseEther("4500000"),
      maxSupply: ethers.utils.parseEther("10000000"),
      graduationThreshold: ethers.utils.parseUnits("15000", 6)
    };

    const createTokenTx = await carbonCoinLauncher.createToken(
      "Test Carbon Coin",
      "TCC",
      deployer.address,
      bondingCurveParams
    );

    const receipt = await createTokenTx.wait();
    const tokenCreatedEvent = receipt.events?.find(e => e.event === 'TokenCreated');
    const tokenAddress = tokenCreatedEvent?.args?.tokenAddress;

    carbonCoin = await ethers.getContractAt("CarbonCoin", tokenAddress);
  });

  it("should have the correct name and symbol", async () => {
    expect(await carbonCoin.name()).to.equal("Test Carbon Coin");
    expect(await carbonCoin.symbol()).to.equal("TCC");
  });
});
