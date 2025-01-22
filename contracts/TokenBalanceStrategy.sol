pragma solidity ^0.8.20;

import "./AbstractResolutionStrategy.sol";
import "./IPredify.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenBalanceStrategy is AbstractResolutionStrategy {
    mapping(uint256 => uint256) public outcomes;

    function getOutcome(
        uint256 marketId,
        bytes calldata resolutionData
    ) external view returns (IPredify.Outcome outcome) {
        require(
            registeredMarkets[marketId] == msg.sender,
            "Only the registered market owner can resolve the outcome"
        );
        (address tokenAddress, address user, int256 minimum) = abi.decode(
            resolutionData,
            (address, address, int256)
        );
        uint256 tokenBalance = IERC20(tokenAddress).balanceOf(user);
        if (minimum >= 0) {
            outcome = tokenBalance >= uint256(minimum)
                ? IPredify.Outcome.Yes
                : IPredify.Outcome.No;
        } else {
            outcome = tokenBalance <= uint256(-minimum)
                ? IPredify.Outcome.Yes
                : IPredify.Outcome.No;
        }
    }
}
