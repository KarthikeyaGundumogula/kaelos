//SPDX-License-Identifier: MIT

/**
 * @title AuctionHouse
 * @author Karthikeya Gundumogula
 * @dev The Liquidation contract calls this contract to execute auctions
 */
pragma solidity ^0.8.20;

interface IRateAggregator {
    function currentAuctionPrice(uint256 initialPrice, uint256 timeElapsed) external view returns(uint256 price);
}

contract AuctionHouse {

    IRateAggregator private s_rateAggregator;

    constructor(address _rateAggregator) {
       s_rateAggregator = IRateAggregator(_rateAggregator);
    }
}
