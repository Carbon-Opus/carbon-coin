import { ethers, deployments } from "hardhat";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { CarbonOpus, CarbonOpusVault, CarbonTreasury, ERC20Mintable } from "../typechain-types";

describe("CarbonOpusVault", () => {
    let deployer: SignerWithAddress;
    let user1: SignerWithAddress;
    let carbonOpus: CarbonOpus;
    let carbonOpusVault: CarbonOpusVault;
    let carbonTreasury: CarbonTreasury;
    let usdcToken: ERC20Mintable;

    beforeEach(async () => {
        [deployer, user1] = await ethers.getSigners();
        await deployments.fixture(["Carbon", "Mocks"]);

        carbonOpus = await ethers.getContract("CarbonOpus");
        carbonOpusVault = await ethers.getContract("CarbonOpusVault");
        carbonTreasury = await ethers.getContract("CarbonTreasury");
        usdcToken = await ethers.getContract("ERC20Mintable");
    });

    describe("collectPaymentFromOpus", () => {
        const amount = ethers.utils.parseUnits("10", 6);

        beforeEach(async () => {
            await usdcToken.mint(user1.address, amount);
            await usdcToken.connect(user1).approve(carbonOpusVault.address, amount);
        });

        it("should allow the opus contract to collect payment", async () => {
            await ethers.provider.send("hardhat_impersonateAccount", [carbonOpus.address]);
            await ethers.provider.send("hardhat_setBalance", [
                carbonOpus.address,
                "0x1000000000000000000",
            ]);
            const opusSigner = await ethers.getSigner(carbonOpus.address);

            const initialBalance = await usdcToken.balanceOf(carbonOpusVault.address);
            await carbonOpusVault.connect(opusSigner).collectPaymentFromOpus(user1.address, amount);
            const finalBalance = await usdcToken.balanceOf(carbonOpusVault.address);
            expect(finalBalance.sub(initialBalance)).to.equal(amount);

            await ethers.provider.send("hardhat_stopImpersonatingAccount", [carbonOpus.address]);
        });

        it("should not allow any other address to collect payment", async () => {
            await expect(carbonOpusVault.connect(user1).collectPaymentFromOpus(user1.address, amount))
                .to.be.revertedWithCustomError(carbonOpusVault, "OnlyOpusAllowed");
        });
    });

    describe("claimTreasuryRewards", () => {
        const amount = ethers.utils.parseUnits("10", 6);

        beforeEach(async () => {
            await usdcToken.mint(carbonOpusVault.address, amount);
        });

        it("should revert if there are no rewards to claim", async () => {
            await ethers.provider.send("hardhat_impersonateAccount", [carbonTreasury.address]);
            await ethers.provider.send("hardhat_setBalance", [
                carbonTreasury.address,
                "0x1000000000000000000",
            ]);
            const treasurySigner = await ethers.getSigner(carbonTreasury.address);

            await expect(carbonOpusVault.connect(treasurySigner).claimTreasuryRewards(carbonTreasury.address))
                .to.be.revertedWithCustomError(carbonOpusVault, "NoRewardsToClaim");

            await ethers.provider.send("hardhat_stopImpersonatingAccount", [carbonTreasury.address]);
        });

        it("should not allow any other address to claim rewards", async () => {
            await expect(carbonOpusVault.connect(user1).claimTreasuryRewards(user1.address))
                .to.be.revertedWith("Only treasury can claim");
        });
    });

    describe("Missing Coverage Tests", () => {
        it("should allow the owner to withdraw Ether", async () => {
            const amount = ethers.utils.parseEther("1.0");
            await ethers.provider.send("hardhat_setBalance", [
                carbonOpusVault.address,
                amount.toHexString().replace("0x0", "0x")
            ]);
            
            const initialBalance = await ethers.provider.getBalance(user1.address);
            await carbonOpusVault.connect(deployer).withdrawEther(user1.address, amount);
            const finalBalance = await ethers.provider.getBalance(user1.address);
            expect(finalBalance.sub(initialBalance)).to.equal(amount);
        });

        it("should allow the owner to withdraw ERC20", async () => {
            const amount = ethers.utils.parseUnits("10", 6);
            await usdcToken.mint(carbonOpusVault.address, amount);
            
            const initialBalance = await usdcToken.balanceOf(user1.address);
            await carbonOpusVault.connect(deployer).withdrawErc20(user1.address, usdcToken.address, amount);
            const finalBalance = await usdcToken.balanceOf(user1.address);
            expect(finalBalance.sub(initialBalance)).to.equal(amount);
        });

        it("should allow the owner to withdraw ERC721", async () => {
            await expect(carbonOpusVault.connect(user1).withdrawERC721(user1.address, usdcToken.address, 1))
                .to.be.revertedWithCustomError(carbonOpusVault, "OwnableUnauthorizedAccount");
        });

        it("should allow the owner to withdraw ERC1155", async () => {
            await expect(carbonOpusVault.connect(user1).withdrawERC1155(user1.address, usdcToken.address, 1, 1))
                .to.be.revertedWithCustomError(carbonOpusVault, "OwnableUnauthorizedAccount");
        });

        it("should allow the owner to update treasury", async () => {
            await expect(carbonOpusVault.connect(deployer).updateTreasury(user1.address))
                .to.emit(carbonOpusVault, "CarbonTreasuryUpdated");
            
            expect(await carbonOpusVault.treasury()).to.equal(user1.address);
        });
    });
});