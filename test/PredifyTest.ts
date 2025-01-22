import { ethers } from "hardhat";
import { expect } from "chai";
import { Contract, Signer } from "ethers";

describe("IPredify with TokenBalanceStrategy", function () {
  let predify: any;
  let tokenBalanceStrategy: any;
  let mockERC20: any;
  let owner: Signer, user1: Signer, user2: Signer;
  let marketId = 1;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy Mock ERC20 Token
    const ERC20 = await ethers.getContractFactory("MockERC20");
    mockERC20 = await ERC20.deploy();
    await mockERC20.waitForDeployment();

    // Deploy the TokenBalanceStrategy
    const TokenBalanceStrategy = await ethers.getContractFactory(
      "TokenBalanceStrategy"
    );
    tokenBalanceStrategy = await TokenBalanceStrategy.deploy();
    await tokenBalanceStrategy.waitForDeployment();

    // Deploy the Predify contract (replace with actual contract name)
    const Predify = await ethers.getContractFactory("Predify");
    predify = await Predify.deploy();
    await predify.waitForDeployment();
  });

  it("Should create a market with TokenBalanceStrategy", async function () {
    const votingStartTime = Math.floor(Date.now() / 1000);
    const votingEndTime = votingStartTime + 86400; // +1 day

    const tx = await predify.createMarket(
      marketId,
      "Does user1 hold at least 100 TTK?",
      tokenBalanceStrategy.target, // Resolution strategy
      ethers.solidityPacked(
        ["address", "address", "int256"],
        [mockERC20.target, await user1.getAddress(), 100]
      ),
      votingStartTime,
      votingEndTime,
      mockERC20.target, // Betting with ERC20 token
      100// Creator fee: 1%
    );

    await expect(tx)
      .to.emit(predify, "MarketCreated")
      .withArgs(
        marketId,
        await owner.getAddress(),
        100,
        mockERC20.target,
        votingStartTime,
        votingEndTime,
        tokenBalanceStrategy.target
      );
  });

  it("Should resolve the market correctly based on user1's token balance", async function () {
    // Mint 50 TTK to user1 (below threshold)
    await mockERC20.mint(await user1.getAddress(), 50);

    // Create the market
    await predify.createMarket(
      marketId,
      "Does user1 hold at least 100 TTK?",
      tokenBalanceStrategy.target,
      ethers.solidityPacked(
        ["address", "address", "int256"],
        [mockERC20.target, await user1.getAddress(), 100]
      ),
      Math.floor(Date.now() / 1000), // Voting Start Time
      Math.floor(Date.now() / 1000) + 86400, // Voting End Time
      mockERC20.target, // Betting with ERC20 token
      100// Creator fee: 1%
    );

    // Fast forward time
    await ethers.provider.send("evm_increaseTime", [86400]); // 1 day
    await ethers.provider.send("evm_mine", []);

    // Resolve market (should be NO because user1 has only 50 TTK)
    const tx = await predify.resolveMarket(marketId);
    await expect(tx).to.emit(predify, "MarketResolved").withArgs(marketId, 2); // Outcome.No
  });

  it("Should resolve the market as YES when user1 has sufficient tokens", async function () {
    // Mint 150 TTK to user1 (above threshold)
    await mockERC20.mint(await user1.getAddress(), 150);

    // Create the market
    await predify.createMarket(
      marketId,
      "Does user1 hold at least 100 TTK?",
      tokenBalanceStrategy.target,
      ethers.solidityPacked(
        ["address", "address", "int256"],
        [mockERC20.target, await user1.getAddress(), 100]
      ),
      Math.floor(Date.now() / 1000), // Voting Start Time
      Math.floor(Date.now() / 1000) + 86400, // Voting End Time
      mockERC20.target, // Betting with ERC20 token
      100// Creator fee: 1%
    );

    // Fast forward time
    await ethers.provider.send("evm_increaseTime", [86400]); // 1 day
    await ethers.provider.send("evm_mine", []);

    // Resolve market (should be YES)
    const tx = await predify.resolveMarket(marketId);
    await expect(tx).to.emit(predify, "MarketResolved").withArgs(marketId, 1); // Outcome.Yes
  });

  it("Should allow user1 to claim winnings", async function () {
    // Mint tokens, create a market, bet, and resolve as YES
    await mockERC20.mint(await user1.getAddress(), 150);
    await predify.createMarket(
      marketId,
      "Does user1 hold at least 100 TTK?",
      tokenBalanceStrategy.target,
      ethers.solidityPacked(
        ["address", "address", "int256"],
        [mockERC20.target, await user1.getAddress(), 100]
      ),
      Math.floor(Date.now() / 1000),
      Math.floor(Date.now() / 1000) + 86400,
      mockERC20.target,
      100// Creator fee: 1%
    );

    await predify.connect(user1).predict(marketId, ethers.parseEther("1"), 1, { value: ethers.parseEther("1") });

    await ethers.provider.send("evm_increaseTime", [86400]); // 1 day
    await ethers.provider.send("evm_mine", []);
    await predify.resolveMarket(marketId);

    const claimTx = await predify.connect(user1).claim(marketId, ethers.ZeroAddress, 0);
    await expect(claimTx)
      .to.emit(predify, "ClaimedProceeds")
      .withArgs(marketId, await user1.getAddress(), ethers.parseEther("1"), 0, ethers.parseEther("0.01"));
  });
});
