pragma solidity ^0.8.20;

import "./AbstractResolutionStrategy.sol";

contract ManualResolutionStrategy is AbstractResolutionStrategy {
    mapping(uint256 => mapping(address => Outcome)) public outcomes;

    function registerOutcome(uint256 marketId, uint256 outcome) public {
        require(outcome == 1 || outcome == 2, "Invalid outcome");
        outcomes[marketId][msg.sender] = Outcome(outcome);
    }

    function getOutcome(
        uint256 marketId,
        bytes calldata resolutionData
    ) external view returns (Outcome) {
        address resolver = abi.decode(resolutionData, (address));
        return outcomes[marketId][resolver];
    }
}
