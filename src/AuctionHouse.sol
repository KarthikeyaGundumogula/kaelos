//SPDX-License-Identifier: MIT

/**
 * @title AuctionHouse
 * @author Karthikeya Gundumogula
 * @dev The Liquidation contract calls this contract to execute auctions
 */
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceFeedLib} from "./libraries/PriceFeedLib.sol";

interface IRateAggregator {
    function currentAuctionPrice(
        uint256 initialPrice,
        uint256 timeElapsed
    ) external view returns (uint256 price);
}

interface IHeadStation {
    function addKeeperIncentives(
        address _keeper,
        uint _amount,
        bytes32 _collateralId
    ) external;
}

contract AuctionHouse {
    error AuctionHouseError_UnAuthorizedOperation();
    error AuctionHouseError_UnRecognizedOperation();

    struct Auction {
        bytes32 collateralId;
        uint256 auctionPosition;
        uint256 kscToRaise;
        uint256 collateralOnAuction;
        address reserveOwner;
        uint256 auctionStartTime;
        uint256 initialPrice;
    }
    struct Collateral {
        uint256 intialIncrement; // Multiplicative factor to increase starting price                  [ray]
        uint256 thresholdTime; // Time elapsed before auction reset                                 [seconds]
        uint256 thresholdPrice; // Percentage drop before auction reset                              [ray]
        uint64 keeperIncentive; // Percentage of kscToRaise to suck from vow to incentivize keepers         [wad]
        uint192 keeperTip; // Flat fee to suck from vow to incentivize keepers                  [rad]
        address priceFeed;
        uint256 totalAuctions;
    }

    using PriceFeedLib for AggregatorV3Interface;

    IRateAggregator private s_rateAggregator;
    IHeadStation private s_headStation;
    mapping(bytes32 collateralId => Collateral collateral)
        private s_collaterals;
    mapping(bytes32 collateralId => uint256[] auctionIds)
        private s_collateralActiveAuctions;
    mapping(uint256 auctionId => Auction auction) private s_auctions;
    mapping(address user => bool) private s_authorizedAddresses;

    constructor(address _rateAggregator, address _headStation) {
        s_rateAggregator = IRateAggregator(_rateAggregator);
        s_headStation = IHeadStation(_headStation);
        s_authorizedAddresses[msg.sender] = true;
    }

    //--Authorization and Administration--//
    modifier authenticate() {
        if (!s_authorizedAddresses[msg.sender]) {
            revert AuctionHouseError_UnAuthorizedOperation();
        }
        _;
    }

    function addAuthorizedAddress(address _user) external authenticate {
        s_authorizedAddresses[_user] = true;
    }

    function removeAuthorizedAddress(address _user) external authenticate {
        s_authorizedAddresses[_user] = false;
    }

    function updateCollateralParams(
        bytes32 _collateralId,
        bytes32 _feild,
        uint256 _value
    ) external authenticate {
        if (_feild == "initialIncrement") {
            s_collaterals[_collateralId].intialIncrement = _value;
        } else if (_feild == "thresholdTime") {
            s_collaterals[_collateralId].thresholdTime = _value;
        } else if (_feild == "thresholdPrice") {
            s_collaterals[_collateralId].thresholdPrice = _value;
        } else if (_feild == "keeperIncentive") {
            s_collaterals[_collateralId].keeperIncentive = uint64(_value);
        } else if (_feild == "keeperTip") {
            s_collaterals[_collateralId].keeperTip = uint192(_value);
        } else {
            revert AuctionHouseError_UnRecognizedOperation();
        }
    }

    function updateCollateralPriceFeed(
        bytes32 _collateralId,
        address _feed
    ) external authenticate {
        s_collaterals[_collateralId].priceFeed = _feed;
    }

    function updateAddresses(
        bytes32 _feild,
        address _value
    ) external authenticate {
        if (_feild == "rateAggregator") {
            s_rateAggregator = IRateAggregator(_value);
        } else if (_feild == "headStation") {
            s_headStation = IHeadStation(_value);
        } else {
            revert AuctionHouseError_UnRecognizedOperation();
        }
    }

    function startAuction(
        bytes32 _collateralId,
        uint256 _collateralAmount,
        uint256 _debtAmount,
        address _reserveOwner,
        address _keeper
    ) external authenticate{
        
    }

    function _getPriceOfCollateralInUSD(
        address _feed,
        uint256 _amount
    ) internal view returns (uint256 value) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_feed);
        value = priceFeed.getUSDValueForTokenAmount(_amount);
    }
}
