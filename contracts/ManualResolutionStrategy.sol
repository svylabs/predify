pragma solidity ^0.8.20;

import "./AbstractResolutionStrategy.sol";

contract ManualResolutionStrategy is AbstractResolutionStrategy {
    mapping(uint256 => mapping(address => Outcome)) public outcomes;

    function registerOutcome(uint256 marketId, Outcome outcome) public {
        require(
            outcome == Outcome.Yes || outcome == Outcome.No,
            "Invalid outcome"
        );
        outcomes[marketId][msg.sender] = Outcome(outcome);
    }

    function getOutcome(
        uint256 marketId,
        bytes calldata resolutionData
    ) external view returns (Outcome) {
        address resolver = abi.decode(resolutionData, (address));
        if (outcomes[marketId][resolver] == Outcome.None) {
            revert("Outcome not registered");
        }
        return outcomes[marketId][resolver];
    }
}
