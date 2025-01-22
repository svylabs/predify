pragma solidity ^0.8.20;

import "./AbstractResolutionStrategy.sol";
import "./IPredify.sol";

contract ManualResolutionStrategy is AbstractResolutionStrategy {
    mapping(uint256 => mapping(address => IPredify.Outcome)) public outcomes;

    function registerOutcome(
        uint256 marketId,
        IPredify.Outcome outcome
    ) public {
        require(
            outcome == IPredify.Outcome.Yes || outcome == IPredify.Outcome.No,
            "Invalid outcome"
        );
        outcomes[marketId][msg.sender] = outcome;
    }

    function getOutcome(
        uint256 marketId,
        bytes calldata resolutionData
    ) external view returns (IPredify.Outcome) {
        address resolver = abi.decode(resolutionData, (address));
        if (outcomes[marketId][resolver] == IPredify.Outcome.None) {
            revert("Outcome not registered");
        }
        return outcomes[marketId][resolver];
    }
}
