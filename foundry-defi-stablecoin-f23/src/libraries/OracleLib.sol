// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {AggregatorV3Interface} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
/*
 * @title: OracleLib
 * @author: Shane Wang
 * @notice: This library is used to check the chainlink Oracle for stale data
 * If a price is stale, the function will revert, and render the DSCEngine unusable - this is by design
 * We want the DSCEngine to freeze if prices become stale.
 * 
 * So if the chainlink network explodes and you heve a lot of money locked in the protocol ... to bad.
 */

library OracleLib {
    error OracleLib__StalePrice();
    // https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1#ethereum-mainnet

    uint256 private constant TIMEOUT = 3 hours; // 3 * 60 * 60 = 10800 seconds

    function staleCheckLastestRoundData(AggregatorV3Interface priceFeeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeeed.latestRoundData();

        uint256 secondsSince = block.timestamp - updatedAt;

        if (secondsSince > TIMEOUT) {
            revert OracleLib__StalePrice();
        }

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
