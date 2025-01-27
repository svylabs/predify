import { ethers } from "hardhat";
import { time }  from '@nomicfoundation/hardhat-network-helpers';
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
      ethers.AbiCoder.defaultAbiCoder().encode(
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

  describe("Betting with ERC20 tokens", function () {
    it("Should resolve the market correctly based on user1's token balance", async function () {
        // Mint 50 TTK to user1 (below threshold)
        let txn = await mockERC20.mint(await user1.getAddress(), BigInt(50 * 10 ** 18));
        await txn.wait();

        const votingStartTime = await time.latest();
        const votingEndTime = votingStartTime + 86400; // +1 day

        // Create the market
        const tx1 = await predify.createMarket(
            marketId,
            "Does user1 hold at least 100 TTK?",
            tokenBalanceStrategy.target,
            ethers.AbiCoder.defaultAbiCoder().encode(
                ["address", "address", "int256"],
                [mockERC20.target, await user1.getAddress(), BigInt(100 * 10 ** 18)]
            ),
            votingStartTime, // Voting Start Time
            votingEndTime, // Voting End Time
            mockERC20.target, // Betting with ERC20 token
            100// Creator fee: 1%
        );

        await expect(tx1)
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

            await time.increaseTo(votingEndTime + 20000); 

        let market = await predify.markets(marketId);
        console.log("Market ", market, " end time: ", votingEndTime + 86400, " current time: ", await time.latest());

        // Resolve market (should be NO because user1 has only 50 TTK)
        const tx = await predify.resolveMarket(marketId);
        await expect(tx).to.emit(predify, "MarketResolved").withArgs(marketId, 2); // Outcome.No
    });
  });

  describe("Betting with ERC20 - working", function() {
    it("Should resolve the market as YES when user1 has sufficient tokens", async function () {
        // Mint 150 TTK to user1 (above threshold)
        let txn = await mockERC20.mint(await user1.getAddress(), BigInt(150 * 10 ** 18));
        await txn.wait();

        const votingStartTime = await time.latest();
        const votingEndTime = votingStartTime + 86400; // +1 day
    
        // Create the market
        const tx1 = await predify.createMarket(
          marketId,
          "Does user1 hold at least 100 TTK?",
          tokenBalanceStrategy.target,
          ethers.AbiCoder.defaultAbiCoder().encode(
            ["address", "address", "int256"],
            [mockERC20.target, await user1.getAddress(), BigInt(100 * 10 ** 18)]
          ),
          votingStartTime,
          votingEndTime, // Voting End Time
          mockERC20.target, // Betting with ERC20 token
          100// Creator fee: 1%
        );

        await expect(tx1)
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
    
        await time.increaseTo(votingEndTime + 10000); // 1 day
        let market = await predify.markets(marketId);
        console.log("Market ", market, " end time: ", votingEndTime + 86400, " current time: ", await time.latest());
    
        // Resolve market (should be YES)
        const tx = await predify.resolveMarket(marketId);
        await expect(tx).to.emit(predify, "MarketResolved").withArgs(marketId, 1); // Outcome.Yes
      });
  })

  it("Should allow user1 to claim winnings", async function () {
    // Mint tokens, create a market, bet, and resolve as YES
    let txn = await mockERC20.mint(await user1.getAddress(), ethers.parseEther("150"));
    await txn.wait();

    const votingStartTime = await time.latest();
    const votingEndTime = votingStartTime + 86400; // +1 day


    await predify.createMarket(
      marketId,
      "Does user1 hold at least 100 TTK?",
      tokenBalanceStrategy.target,
      ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "address", "int256"],
        [mockERC20.target, await user1.getAddress(), ethers.parseEther("100")]
      ),
      votingStartTime,
      votingEndTime,
      mockERC20.target,
      100// Creator fee: 1%
    );

    txn = await mockERC20.connect(user1).approve(predify.target, ethers.parseEther("1"));
    await txn.wait();
    txn = await predify.connect(user1).predict(marketId, ethers.parseEther("1"), 1);
    await txn.wait();

    await time.increase(86400); // 1 day
    txn = await predify.resolveMarket(marketId);
    await txn.wait();

    let market = await predify.markets(marketId);
    console.log("Market ", market, " end time: ", votingEndTime + 86400, " current time: ", await time.latest());

    const claimTx = await predify.connect(user1).claim(marketId, ethers.ZeroAddress, 0);
    await expect(claimTx)
      .to.emit(predify, "ClaimedProceeds")
      .withArgs(marketId, await user1.getAddress(), 1, ethers.parseEther("0"), 0, ethers.parseEther("0.00"));
  });
});
