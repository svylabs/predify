pragma solidity ^0.8.20;

import "./AbstractResolutionStrategy.sol";
import "./IPredify.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenBalanceStrategy is AbstractResolutionStrategy {
    function resolve(
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
        uint256 balance = 0;
        if (tokenAddress == address(0)) {
            balance = tokenAddress.balance;
        } else {
            balance = IERC20(tokenAddress).balanceOf(user);
        }
        if (minimum >= 0) {
            outcome = balance >= uint256(minimum)
                ? IPredify.Outcome.Yes
                : IPredify.Outcome.No;
        } else {
            outcome = balance <= uint256(-minimum)
                ? IPredify.Outcome.Yes
                : IPredify.Outcome.No;
        }
    }
}
