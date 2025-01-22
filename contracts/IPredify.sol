pragma solidity ^0.8.20;

interface IPredify {
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
        Outcome outcome;
        uint256 creatorFee;
    }

    enum Outcome {
        None,
        Yes,
        No,
        Abort
    }

    function createMarket(
        uint256 marketId,
        string memory description,
        address resolutionStrategy,
        bytes calldata resolutionData,
        uint256 votingEndTime,
        uint256 votingStartTime,
        address betTokenAddress,
        uint256 creatorFee
    ) external;

    function vote(
        uint256 marketId,
        uint256 betValue,
        Outcome predictedOutcome
    ) external payable;

    function resolveMarket(uint256 marketId) external;

    function claim(
        uint256 marketId,
        address frontend,
        uint256 frontendFee
    ) external;

    function withdrawBet(uint256 marketId) external;
}
