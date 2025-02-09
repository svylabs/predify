pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IPredify.sol";
import "./IResolutionStrategy.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * Predify is a permissionless binary prediction market for DeFi.
 *
 * Creators can create prediction markets using inbuilt resolution strategies, users can participate by simply betting on the outcome and developers can build custom onchain or
 * offchain resolution strategies to resolve the outcome of prediction.
 *
 * Some example markets could be:
 * 1. Will a governance vote pass in a certain protocol?
 * 2. Will a protocol reach a certain TVL in terms of number of ETH or number of tokens in 2 days?
 * 3. Will a protocol be exploited in the next 7 days?
 * 4. Will the number of tokens staked in a protocol increase by 5 million in the next 10 days?
 * 5. Will the total number of tokens issued by the protocol increase to a certain value in the next 30 days?
 *
 * Some protocols use data that is directly on chain to determine the outcome of prediction, while others must use off-chain data sources.
 *
 * The protocol tracks the outcome of predictions based on the configured strategy at the time of creation of market, and rewards users who bet on the correct outcome.
 *
 */
contract Predify is IPredify, ReentrancyGuard {
    mapping(uint256 => PredictionMarket) public markets;

    uint256 public constant MAX_OUTCOME_RESOLUTION_TIME = 1 days;

    uint256 public constant MAX_PERCENTAGE = 10000;

    mapping(uint256 => mapping(address => mapping(Outcome => uint256)))
        public bets;

    constructor() {}

    function createMarket(
        uint256 marketId,
        string memory description,
        address resolutionStrategy,
        bytes calldata resolutionData,
        uint256 votingStartTime,
        uint256 votingEndTime,
        address betTokenAddress,
        uint256 creatorFee
    ) public {
        require(
            markets[marketId].creator == address(0) &&
                markets[marketId].votingStartTime == 0,
            "Market already exists"
        );
        if (votingStartTime == 0) {
            votingStartTime = block.timestamp;
        }
        require(creatorFee < MAX_PERCENTAGE, "Creator fee too high");
        markets[marketId] = PredictionMarket({
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
            outcome: Outcome.None
        });
        require(
            IResolutionStrategy(resolutionStrategy).registerMarket(marketId),
            "Market registration failed"
        );
        emit MarketCreated(
            marketId,
            msg.sender,
            creatorFee,
            betTokenAddress,
            votingStartTime,
            votingEndTime,
            resolutionStrategy
        );
    }

    function predict(
        uint256 marketId,
        uint256 betValue,
        Outcome predictedOutcome
    ) public payable nonReentrant {
        require(
            block.timestamp >= markets[marketId].votingStartTime,
            "Voting has not started yet"
        );
        require(
            block.timestamp <= markets[marketId].votingEndTime,
            "Voting has ended"
        );
        require(
            (predictedOutcome != Outcome.None &&
                predictedOutcome != Outcome.Abort),
            "Can't predict this outcome"
        );

        require(betValue > 0, "Bet value must be greater than 0");

        _requireBetTokenTransfer(
            markets[marketId].betTokenAddress,
            msg.sender,
            betValue
        );

        markets[marketId].totalBetAmount += betValue;

        uint256 totalBets = 0;

        if (predictedOutcome == Outcome.Yes) {
            markets[marketId].totalYesBetAmount += betValue;
            totalBets = markets[marketId].totalYesBetAmount;
        } else {
            markets[marketId].totalNoBetAmount += betValue;
            totalBets = markets[marketId].totalNoBetAmount;
        }

        bets[marketId][msg.sender][predictedOutcome] += betValue;
        emit Prediction(
            marketId,
            msg.sender,
            predictedOutcome,
            betValue,
            bets[marketId][msg.sender][predictedOutcome],
            totalBets
        );
    }

    function resolveMarket(uint256 marketId) public {
        require(markets[marketId].votingStartTime > 0, "Market does not exist");
        require(
            block.timestamp > markets[marketId].votingEndTime,
            "Voting has not ended yet"
        );

        require(
            block.timestamp <
                markets[marketId].votingEndTime + MAX_OUTCOME_RESOLUTION_TIME,
            "Outcome resolution time has passed"
        );

        require(
            markets[marketId].outcome == Outcome.None,
            "Market outcome already resolved"
        );

        Outcome outcome = IResolutionStrategy(
            markets[marketId].resolutionStrategy
        ).resolve(marketId, markets[marketId].resolutionData);

        markets[marketId].outcome = outcome;

        emit MarketResolved(marketId, outcome);
    }

    function claim(
        uint256 marketId,
        address frontend,
        uint256 frontendFee
    ) public nonReentrant {
        require(frontendFee < MAX_PERCENTAGE, "Frontend fee too high");
        Outcome outcome = markets[marketId].outcome;
        require(
            (outcome != Outcome.None && outcome != Outcome.Abort),
            "Market outcome not resolved yet"
        );
        require(
            block.timestamp > markets[marketId].votingEndTime,
            "Voting has not ended yet"
        );

        uint256 totalWinnings = 0;
        uint256 betValueReturn = 0;

        if (outcome == Outcome.Yes) {
            betValueReturn = bets[marketId][msg.sender][Outcome.Yes];
            totalWinnings =
                (markets[marketId].totalNoBetAmount * betValueReturn) /
                markets[marketId].totalYesBetAmount;
            bets[marketId][msg.sender][Outcome.Yes] = 0;
        } else if (outcome == Outcome.No) {
            betValueReturn = bets[marketId][msg.sender][Outcome.No];
            totalWinnings =
                (markets[marketId].totalYesBetAmount * betValueReturn) /
                markets[marketId].totalNoBetAmount;
            bets[marketId][msg.sender][Outcome.No] = 0;
        }

        uint256 creatorFee = (totalWinnings * markets[marketId].creatorFee) /
            MAX_PERCENTAGE;

        uint256 frontendFeeAmount = 0;
        if (frontendFee > 0) {
            frontendFeeAmount = (totalWinnings * frontendFee) / MAX_PERCENTAGE;
        }

        _requireTransfer(
            markets[marketId].betTokenAddress,
            msg.sender,
            totalWinnings - creatorFee - frontendFeeAmount
        );
        _requireTransfer(
            markets[marketId].betTokenAddress,
            markets[marketId].creator,
            creatorFee
        );
        if (frontendFeeAmount > 0) {
            _requireTransfer(
                markets[marketId].betTokenAddress,
                frontend,
                frontendFeeAmount
            );
        }
        if (betValueReturn > 0) {
            _requireTransfer(
                markets[marketId].betTokenAddress,
                msg.sender,
                betValueReturn
            );
        }
        emit ClaimedProceeds(
            marketId,
            msg.sender,
            outcome,
            betValueReturn,
            totalWinnings,
            creatorFee,
            frontendFeeAmount
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

    function _requireTransfer(
        address tokenAddress,
        address receiver,
        uint256 amount
    ) private {
        if (amount > 0) {
            if (tokenAddress == address(0)) {
                payable(receiver).transfer(amount);
            } else {
                IERC20 token = IERC20(tokenAddress);
                require(
                    token.transfer(receiver, amount),
                    "Bet token transfer failed"
                );
            }
        }
    }

    function withdrawBet(uint256 marketId) public {
        // Only if aborted or outcome not resolved in time
        Outcome outcome = markets[marketId].outcome;
        require(
            ((block.timestamp >
                markets[marketId].votingEndTime +
                    MAX_OUTCOME_RESOLUTION_TIME) && outcome == Outcome.None) || // 1 day grace period
                outcome == Outcome.Abort,
            "Market outcome not aborted"
        );

        if (outcome == Outcome.None) {
            markets[marketId].outcome = Outcome.Abort;
            emit MarketResolved(marketId, Outcome.Abort);
        }

        uint256 yesBets = bets[marketId][msg.sender][Outcome.Yes];
        uint256 noBets = bets[marketId][msg.sender][Outcome.No];
        if (yesBets > 0) {
            bets[marketId][msg.sender][Outcome.Yes] = 0;
            _requireTransfer(
                markets[marketId].betTokenAddress,
                msg.sender,
                yesBets
            );
        }
        if (noBets > 0) {
            bets[marketId][msg.sender][Outcome.No] = 0;
            _requireTransfer(
                markets[marketId].betTokenAddress,
                msg.sender,
                noBets
            );
        }
        emit BetWithdrawn(marketId, msg.sender, yesBets, noBets);
    }
}
