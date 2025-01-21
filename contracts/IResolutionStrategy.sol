pragma solidity ^0.8.20;

interface IResolutionStrategy {
    enum Outcome {
        None,
        Yes,
        No,
        Abort
    }

    function registerMarket(uint256 marketId) external;

    /**
     *
     * Returns:
     * 1 - Yes
     * 2 - No
     */
    function getOutcome(
        uint256 marketId,
        bytes calldata resolutionData
    ) external returns (Outcome);
}
