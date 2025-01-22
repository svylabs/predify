pragma solidity ^0.8.20;

import "./IResolutionStrategy.sol";

abstract contract AbstractResolutionStrategy is IResolutionStrategy {
    mapping(uint256 => address) public registeredMarkets;

    function registerMarket(uint256 marketId) public returns (bool) {
        require(
            registeredMarkets[marketId] == address(0),
            "Market already registered"
        );
        registeredMarkets[marketId] = msg.sender;
        return true;
    }
}
