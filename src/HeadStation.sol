//SPDX-License-Identifier: MIT
/**
 * @title HeadStation
 * @author KAarthikeya Gundumogula
 * @notice This is the core station of the Kel Stable Coin
 * @dev this contract stores the state of the Utopia Ecosystem
 */
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceFeedLib} from "./libraries/PriceFeedLib.sol";

contract HeadStation {
    error HeadStationError_UnAuthorizedOperation();
    error HeadStationError_CollateralAlreadyInitialized();
    error HeadStationError_SafetyIndexLessThanOne(uint safetyIndex);
    error HeadStationError_UnRecognizedOperation();

    struct CollateralType {
        uint256 totalDebtOnThisCollateral;
        uint256 upperLimitOnCollateral;
        uint256 minDebtOnCollateral;
        uint256 stabilityFee; //calculated persecond
        uint256 liquidationThreshold;
        address priceFeedAddress;
    }
    struct Reserve {
        uint256 _totalCollateral;
        uint256 _totalKSCMinted;
    }

    using PriceFeedLib for AggregatorV3Interface;
    uint256 private constant THRESHOLD_PRECISION = 100;
    uint256 public TotalDebtCeiling;
    mapping(bytes32 collateralId => CollateralType collateral)
        private s_collaterals;
    mapping(bytes32 collateralType => mapping(address user => Reserve reserve))
        private s_reserves;
    mapping(address user => bool allowed) public s_authorizedAddresses;

    constructor() {
        s_authorizedAddresses[msg.sender] = true;
    }

    //--Events--//
    event NewCollateralAdded(bytes32 ID);
    event CollateralTokenUpdated(string feild, uint256 Value);

    //--Authentication & Administration--//
    modifier authenticate() {
        if (s_authorizedAddresses[msg.sender] != true) {
            revert HeadStationError_UnAuthorizedOperation();
        }
        _;
    }

    function addAuthorizedAddress(address _user) external authenticate {
        s_authorizedAddresses[_user] = true;
    }

    function removeAuthorizedAddress(address _user) external authenticate {
        s_authorizedAddresses[_user] = false;
    }

    function initializeCollateralToken(
        bytes32 _collateralId,
        address _priceFeedaddress
    ) external authenticate {
        if (s_collaterals[_collateralId].stabilityFee != 0) {
            revert HeadStationError_CollateralAlreadyInitialized();
        }
        s_collaterals[_collateralId].priceFeedAddress = _priceFeedaddress;
    }

    function updateCollateralToken(
        bytes32 _collateralType,
        bytes32 _feild,
        uint256 _value
    ) external authenticate {
        if (_feild == "upperLimit") {
            s_collaterals[_collateralType].upperLimitOnCollateral = _value;
        } else if (_feild == "lowerLimit") {
            s_collaterals[_collateralType].minDebtOnCollateral = _value;
        } else if (_feild == "liquidationThreshold") {
            s_collaterals[_collateralType].liquidationThreshold = _value;
        } else if(_feild == "stabilityFee") {
            s_collaterals[_collateralType].stabilityFee = _value;
        } else {
            revert HeadStationError_UnRecognizedOperation();
        }
    }

    function depositCollateral(
        bytes32 _collateralType,
        uint256 _amount,
        address _user
    ) external {
        s_reserves[_collateralType][_user]._totalCollateral = _add(
            s_reserves[_collateralType][_user]._totalCollateral,
            _amount
        );
    }

    function withdrawCollateral(
        bytes32 _collateralType,
        uint256 _amount,
        address _user
    ) external {
        s_reserves[_collateralType][_user]._totalCollateral = _sub(
            s_reserves[_collateralType][_user]._totalCollateral,
            _amount
        );
        _revertIfSafetyIndexIsBroken(_collateralType, _user);
    }

    function depositKSC(
        bytes32 _collateralType,
        uint256 _amount,
        address _user
    ) external {
        s_reserves[_collateralType][_user]._totalKSCMinted = _add(
            s_reserves[_collateralType][_user]._totalKSCMinted,
            _amount
        );
    }

    function withdrawKSC(
        bytes32 _collateralType,
        uint256 _amount,
        address _user
    ) external {
        s_reserves[_collateralType][_user]._totalKSCMinted = _sub(
            s_reserves[_collateralType][_user]._totalKSCMinted,
            _amount
        );
        _revertIfSafetyIndexIsBroken(_collateralType, _user);
    }

    //internal and helper functions
    function _calculateSafetyIndex(
        bytes32 _collateralType,
        address _user
    ) internal view returns (uint256 safetyIndex) {
        uint256 collateralThreshold = s_collaterals[_collateralType]
            .liquidationThreshold;
        uint256 reserveCollateral = s_reserves[_collateralType][_user]
            ._totalCollateral;
        uint256 reserveDebt = s_reserves[_collateralType][_user]
            ._totalKSCMinted;
        if (reserveDebt <= 0) {
            return type(uint).max;
        }
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_collaterals[_collateralType].priceFeedAddress
        );
        uint256 collateralValueInUSD = priceFeed.getUSDValueForTokenAmount(
            reserveCollateral
        );
        uint256 collateralToThreshold = (collateralValueInUSD *
            collateralThreshold) / THRESHOLD_PRECISION;
        safetyIndex = collateralToThreshold / reserveDebt;
    }

    function _revertIfSafetyIndexIsBroken(
        bytes32 _collateralType,
        address _user
    ) internal view {
        uint safetyIndex = _calculateSafetyIndex(_collateralType, _user);
        if (safetyIndex < 1) {
            revert HeadStationError_SafetyIndexLessThanOne(safetyIndex);
        }
    }

    // --- Math ---
    function _add(uint x, int y) internal pure returns (uint z) {
        z = x + uint(y);
        require(y >= 0 || z <= x);
        require(y <= 0 || z >= x);
    }

    function _sub(uint x, int y) internal pure returns (uint z) {
        z = x - uint(y);
        require(y <= 0 || z <= x);
        require(y >= 0 || z >= x);
    }

    function _mul(uint x, int y) internal pure returns (int z) {
        z = int(x) * y;
        require(int(x) >= 0);
        require(y == 0 || z / y == int(x));
    }

    function _add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }

    function _sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }

    function _mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }
}
