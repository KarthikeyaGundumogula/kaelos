//SPDX-License-Identifier: MIT

/**
 * @title SolvencyStation
 * @author Karthikeya Gundumogula
 * @notice This contract handles the current prices of Collaterals and calculates the Safety Index for the given Reserve
 */

pragma solidity ^0.8.20;
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceFeedLib} from "./libraries/PriceFeedLib.sol";

interface HeadStation {
    function file(bytes32, bytes32, uint) external;
}

contract SolvencyStation {
    error SolvencyStationError_UnAuthorizedOperation();
    error SolvencyStationError_StationNotLive();

    using PriceFeedLib for AggregatorV3Interface;

    struct Collateral {
        address priceFeed;
        uint256 liquidationThreshold;
    }

    uint256 public constant PRECISION = 10e27;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 10e10;
    uint256 private constant DECIMAL_PRECISION = 10e18;
    uint256 public s_kelCoinValue;
    HeadStation private headStation;
    bool public s_status;
    mapping(bytes32 collateralType => Collateral data)
        public s_collateralTokens;
    mapping(address user => bool authorized) public s_authorizedAddresses;

    //--Events--//
    event StatusUpdated(bool status);
    event AuthorizedAddressAdded(address user);
    event AuthorizedAddressRemoved(address user);

    constructor(address _headStation) {
        headStation = HeadStation(_headStation);
        s_authorizedAddresses[msg.sender] = true;
        s_status = true;
        s_kelCoinValue = PRECISION;
        emit StatusUpdated(s_status);
    }

    //--Authorization & Administration--//
    modifier authorize() {
        if (s_authorizedAddresses[msg.sender] != true) {
            revert SolvencyStationError_UnAuthorizedOperation();
        }
        _;
    }

    function addAuthorizedAddress(address _user) external authorize {
        s_authorizedAddresses[_user] = true;
        emit AuthorizedAddressAdded(_user);
    }

    function removeAuthorizedAddress(address _user) external authorize {
        s_authorizedAddresses[_user] = false;
        emit AuthorizedAddressRemoved(_user);
    }

    function updateStatus() external authorize {
        s_status = !s_status;
        emit StatusUpdated(s_status);
    }

    function updateCollateralPriceFeed(
        address _newPriceFeed,
        bytes32 _collateralType
    ) external authorize {
        if (s_status != true) {
            revert SolvencyStationError_StationNotLive();
        }
        s_collateralTokens[_collateralType].priceFeed = _newPriceFeed;
    }

    function updateKelCoinValue(uint256 _newValue) external authorize {
        if (s_status != true) {
            revert SolvencyStationError_StationNotLive();
        }
        s_kelCoinValue = _newValue;
    }

    function updateLiquidationThreshold(
        bytes32 _collateralType,
        uint256 _newThreshold
    ) external authorize {
        if (s_status != true) {
            revert SolvencyStationError_StationNotLive();
        }
        s_collateralTokens[_collateralType]
            .liquidationThreshold = _newThreshold;
    }
}
