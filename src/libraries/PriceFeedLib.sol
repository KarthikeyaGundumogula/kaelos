// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title PriceFeedLib
 * @author Karthikeya Gundumogula
 * @notice This library is used to check the Chainlink Oracle for stale data.
 * If a price is stale, functions will revert, and render the  HeadStation unusable - this is by design.
 * We want the HeadStation to freeze if prices become stale.
 *
 * So if the Chainlink network explodes and you have a lot of money locked in the protocol... too bad.
 */
library PriceFeedLib {
    error PriceFeedLibError__StalePrice();

    uint256 private constant TIMEOUT = 3 hours;
    uint256 private constant DECIMAL_PRECISION = 10e18;

    function staleCheckLatestRoundData(
        AggregatorV3Interface chainlinkFeed
    ) public view returns (uint80, int256, uint256, uint256, uint80) {
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = chainlinkFeed.latestRoundData();

        if (updatedAt == 0 || answeredInRound < roundId) {
            revert PriceFeedLibError__StalePrice();
        }
        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) revert PriceFeedLibError__StalePrice();

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }

    function getTimeout(
        AggregatorV3Interface /* chainlinkFeed */
    ) public pure returns (uint256) {
        return TIMEOUT;
    }

    //--Price--//
    function getUSDValueForTokenAmount(
        AggregatorV3Interface _chainlinkPriceFeed,
        uint256 _amount
    ) external view returns (uint256 value) {
        (, int256 currentPrice, , , ) = staleCheckLatestRoundData(
            _chainlinkPriceFeed
        );
        value = (uint(currentPrice) * _amount) / DECIMAL_PRECISION;
    }
    function getTokenAmountForUSD(
        AggregatorV3Interface _chainlinkPriceFeed,
        uint _amount
    ) external view returns (uint256 value) {
        (, int256 currentPrice, , , ) = staleCheckLatestRoundData(
            _chainlinkPriceFeed
        );
        value = (_amount * DECIMAL_PRECISION) / uint(currentPrice);
    }
}
