pragma solidity ^0.8.20;

import "./IPredify.sol";

interface IResolutionStrategy {
    function registerMarket(uint256 marketId) external returns (bool);

    /**
     *
     * Returns:
     * 1 - Yes
     * 2 - No
     */
    function getOutcome(
        uint256 marketId,
        bytes calldata resolutionData
    ) external returns (IPredify.Outcome);
}
