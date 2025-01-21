pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IResolutionStrategy.sol";

/**
 * Predify is a prediction market for DeFi. Users can create prediction markets for any DeFi protocol and bet on the outcome of prediction.
 *
 * Some example markets could be:
 * 1. Will a governance vote pass?
 * 2. Will a protocol reach a certain TVL in terms of ETH or token value?
 * 3. Will a protocol be exploited?
 * 4. Will the number of tokens staked in a protocol increase?
 * 5. Will the total number of tokens issued by the protocol increase to a certain value, etc.
 *
 * Some protocols use data that is directly on chain to determine the outcome of prediction, while others must use off-chain data sources.
 *
 * The protocol tracks the outcome of predictions and rewards users who bet on the correct outcome.
 *
 */
contract Predify {
    struct PredictionMarket {
        address creator;
        string description;
        address resolutionStrategy;
        bytes resolutionData;
        uint256 totalBetAmount;
        uint256 totalYesBetAmount;
        uint256 totalNoBetAmount;
        uint256 votingEndTime;
        uint256 votingStartTime;
        address betTokenAddress;
        IResolutionStrategy.Outcome outcome;
        uint256 creatorFee;
    }

    mapping(uint256 => PredictionMarket) public predictionMarkets;

    mapping(uint256 => mapping(address => mapping(IResolutionStrategy.Outcome => uint256)))
        public bets;

    constructor() {}

    function createMarket(
        uint256 marketId,
        string memory description,
        address resolutionStrategy,
        bytes calldata resolutionData,
        uint256 votingEndTime,
        uint256 votingStartTime,
        address betTokenAddress,
        uint256 creatorFee
    ) public {
        predictionMarkets[marketId] = PredictionMarket({
            creator: msg.sender,
            description: description,
            resolutionStrategy: resolutionStrategy,
            resolutionData: resolutionData,
            totalBetAmount: 0,
            totalYesBetAmount: 0,
            totalNoBetAmount: 0,
            votingEndTime: votingEndTime,
            votingStartTime: votingStartTime,
            betTokenAddress: betTokenAddress,
            creatorFee: creatorFee,
            outcome: IResolutionStrategy.Outcome.None
        });
    }

    function vote(
        uint256 marketId,
        uint256 betValue,
        IResolutionStrategy.Outcome predictedOutcome
    ) public payable {
        require(
            block.timestamp >= predictionMarkets[marketId].votingStartTime,
            "Voting has not started yet"
        );
        require(
            block.timestamp <= predictionMarkets[marketId].votingEndTime,
            "Voting has ended"
        );
        require(
            predictedOutcome != IResolutionStrategy.Outcome.None,
            "Can't predict this outcome"
        );

        require(betValue > 0, "Bet value must be greater than 0");

        _requireBetTokenTransfer(
            predictionMarkets[marketId].betTokenAddress,
            msg.sender,
            betValue
        );

        predictionMarkets[marketId].totalBetAmount += betValue;

        if (predictedOutcome == IResolutionStrategy.Outcome.Yes) {
            predictionMarkets[marketId].totalYesBetAmount += betValue;
        } else {
            predictionMarkets[marketId].totalNoBetAmount += betValue;
        }

        bets[marketId][msg.sender][predictedOutcome] += betValue;
    }

    function resolveMarket(uint256 marketId) public {
        require(
            block.timestamp > predictionMarkets[marketId].votingEndTime,
            "Voting has not ended yet"
        );

        predictionMarkets[marketId].outcome = IResolutionStrategy(
            predictionMarkets[marketId].resolutionStrategy
        ).getOutcome(marketId, predictionMarkets[marketId].resolutionData);
    }

    function claimWinningProceeds(uint256 marketId) public {
        require(
            predictionMarkets[marketId].outcome !=
                IResolutionStrategy.Outcome.None,
            "Market outcome not resolved yet"
        );
        require(
            block.timestamp > predictionMarkets[marketId].votingEndTime,
            "Voting has not ended yet"
        );

        uint256 totalWinnings = 0;

        if (
            predictionMarkets[marketId].outcome ==
            IResolutionStrategy.Outcome.Yes
        ) {
            totalWinnings =
                (predictionMarkets[marketId].totalNoBetAmount *
                    bets[marketId][msg.sender][
                        IResolutionStrategy.Outcome.Yes
                    ]) /
                predictionMarkets[marketId].totalYesBetAmount;
            bets[marketId][msg.sender][IResolutionStrategy.Outcome.Yes] = 0;
        } else {
            totalWinnings =
                (predictionMarkets[marketId].totalYesBetAmount *
                    bets[marketId][msg.sender][
                        IResolutionStrategy.Outcome.No
                    ]) /
                predictionMarkets[marketId].totalNoBetAmount;
            bets[marketId][msg.sender][IResolutionStrategy.Outcome.No] = 0;
        }

        uint256 creatorFee = (totalWinnings *
            predictionMarkets[marketId].creatorFee) / 10000;

        _requireBetWinningTransfer(
            predictionMarkets[marketId].betTokenAddress,
            msg.sender,
            totalWinnings - creatorFee
        );
        _requireBetWinningTransfer(
            predictionMarkets[marketId].betTokenAddress,
            predictionMarkets[marketId].creator,
            creatorFee
        );
    }

    function _requireBetTokenTransfer(
        address betTokenAddress,
        address sender,
        uint256 betValue
    ) private {
        if (betTokenAddress == address(0)) {
            require(msg.value == betValue, "Incorrect bet value");
        } else {
            IERC20 betToken = IERC20(betTokenAddress);
            require(
                betToken.transferFrom(sender, address(this), betValue),
                "Bet token transfer failed"
            );
        }
    }

    function _requireBetWinningTransfer(
        address betTokenAddress,
        address receiver,
        uint256 winningAmount
    ) private {
        if (betTokenAddress == address(0)) {
            payable(receiver).transfer(winningAmount);
        } else {
            IERC20 betToken = IERC20(betTokenAddress);
            require(
                betToken.transfer(receiver, winningAmount),
                "Bet token transfer failed"
            );
        }
    }
}
