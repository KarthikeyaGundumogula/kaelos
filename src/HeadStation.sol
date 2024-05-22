//SPDX-License-Identifier: MIT
/**
 * @title HeadStation
 * @author Karthikeya Gundumogula
 * @notice This is the core station of the Kel Stable Coin
 * @dev this contract stores the state of the Utopia Ecosystem
 */
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceFeedLib} from "./libraries/PriceFeedLib.sol";

interface IRateAggregator {
    function calculateStabilityRate(
        bytes32 _collateralId,
        uint256 _oldRate
    ) external returns (uint256 newRate);
}

contract HeadStation {
    error HeadStationError_UnAuthorizedOperation();
    error HeadStationError_ReserveIsSafe();
    error HeadStationError_CollateralAlreadyInitialized();
    error HeadStationError_SafetyIndexLessThanOne(uint safetyIndex);
    error HeadStationError_UnRecognizedOperation();
    error HeadStationError_UnRecognozedCollateralType();

    /**
     * @dev in this struct we store normalized debt which is totaldebt/stabilityRate
     * @dev to get the debt of an reserve or an collateral at any point just multiply the normalizedDebt with the stabilityRate at that point of time
     */
    struct CollateralType {
        uint256 totalDebtOnThisCollateral; //normalized to stability rate
        uint256 upperLimitOnCollateral;
        uint256 minDebtOnCollateral;
        uint256 stabilityRate; //calculated perseconds
        uint256 liquidationThreshold;
        address priceFeedAddress;
    }
    struct Reserve {
        uint256 _totalCollateral;
        uint256 _totalKSCMinted;
    }

    using PriceFeedLib for AggregatorV3Interface;
    IRateAggregator private rateAggregator;
    uint256 private constant THRESHOLD_PRECISION = 100;
    uint256 public s_totalKSCIssued;
    uint256 public TotalDebtCeiling;
    mapping(bytes32 collateralId => CollateralType collateral)
        private s_collaterals;
    mapping(bytes32 collateralType => mapping(address user => Reserve reserve))
        private s_reserves;
    mapping(address user => bool allowed) public s_authorizedAddresses;

    constructor(address _rateAggregator) {
        s_authorizedAddresses[msg.sender] = true;
        rateAggregator = IRateAggregator(_rateAggregator);
    }

    //--Events--//
    event NewCollateralAdded(bytes32 ID);
    event CollateralTokenUpdated(string feild, uint256 Value);

    //--Authentication & Administration--//

    function addAuthorizedAddress(address _user) external {
        _authenticate();
        s_authorizedAddresses[_user] = true;
    }

    function removeAuthorizedAddress(address _user) external {
        _authenticate();
        s_authorizedAddresses[_user] = false;
    }

    function initializeCollateralToken(
        bytes32 _collateralId,
        address _priceFeedaddress
    ) external {
        _authenticate();
        if (s_collaterals[_collateralId].stabilityRate != 0) {
            revert HeadStationError_CollateralAlreadyInitialized();
        }
        s_collaterals[_collateralId].priceFeedAddress = _priceFeedaddress;
    }

    function updateCollateralToken(
        bytes32 _collateralId,
        bytes32 _feild,
        uint256 _value
    ) external {
        _authenticate();
        if (_feild == "upperLimit") {
            s_collaterals[_collateralId].upperLimitOnCollateral = _value;
        } else if (_feild == "lowerLimit") {
            s_collaterals[_collateralId].minDebtOnCollateral = _value;
        } else if (_feild == "liquidationThreshold") {
            s_collaterals[_collateralId].liquidationThreshold = _value;
        } else if (_feild == "stabilityFee") {
            s_collaterals[_collateralId].stabilityRate = _value;
        } else {
            revert HeadStationError_UnRecognizedOperation();
        }
    }

    function depositCollateral(
        bytes32 _collateralType,
        uint256 _amount,
        address _user
    ) external {
        _authenticate();
        if (s_collaterals[_collateralType].stabilityRate == 0) {
            revert HeadStationError_UnRecognozedCollateralType();
        }
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
        _authenticate();
        s_reserves[_collateralType][_user]._totalCollateral = _sub(
            s_reserves[_collateralType][_user]._totalCollateral,
            _amount
        );
        _revertIfSafetyIndexIsBroken(_collateralType, _user);
    }

    function depositKSC(
        bytes32 _collateralId,
        uint256 _amount,
        address _user
    ) external {
        _authenticate();
        if (s_collaterals[_collateralId].stabilityRate == 0) {
            revert HeadStationError_UnRecognozedCollateralType();
        }
        _updateRate(_collateralId);
        s_totalKSCIssued = _sub(s_totalKSCIssued, _amount);
        uint256 rate = s_collaterals[_collateralId].stabilityRate;
        uint256 normalizedAmount = _amount / rate;
        s_reserves[_collateralId][_user]._totalKSCMinted = _sub(
            s_reserves[_collateralId][_user]._totalKSCMinted,
            normalizedAmount
        );
        s_collaterals[_collateralId].totalDebtOnThisCollateral = _sub(
            s_collaterals[_collateralId].totalDebtOnThisCollateral,
            normalizedAmount
        );
    }

    function withdrawKSC(
        bytes32 _collateralId,
        uint256 _amount,
        address _user
    ) external {
        _authenticate();
        if (s_collaterals[_collateralId].stabilityRate == 0) {
            revert HeadStationError_UnRecognozedCollateralType();
        }
        _updateRate(_collateralId);
        s_totalKSCIssued = _sub(s_totalKSCIssued, _amount);
        uint256 rate = s_collaterals[_collateralId].stabilityRate;
        uint256 normalizedAmount = _amount / rate;
        s_reserves[_collateralId][_user]._totalKSCMinted = _add(
            s_reserves[_collateralId][_user]._totalKSCMinted,
            normalizedAmount
        );
        s_collaterals[_collateralId].totalDebtOnThisCollateral = _add(
            s_collaterals[_collateralId].totalDebtOnThisCollateral,
            normalizedAmount
        );
        _revertIfSafetyIndexIsBroken(_collateralId, _user);
    }

    function confiscateReserve(
        bytes32 _collateralId,
        address _reserveOwner,
        int256 _collateral,
        int256 _debtKSC
    ) external {
        _authenticate();
        _updateRate(_collateralId);
        uint256 safetyIndex = _calculateSafetyIndex(
            _collateralId,
            _reserveOwner
        );
        if (safetyIndex > 1) {
            revert HeadStationError_ReserveIsSafe();
        }
        Reserve storage res = s_reserves[_collateralId][_reserveOwner];
        res._totalCollateral = _sub(res._totalCollateral, _collateral);
        res._totalKSCMinted = _sub(res._totalKSCMinted, _debtKSC);
    }

    function addKeeperIncentives(
        address _keeper,
        uint _amount,
        bytes32 _collateralId
    ) external {
        _updateRate(_collateralId);
        uint256 normalizedAmount = _amount /
            s_collaterals[_collateralId].stabilityRate;
        s_reserves[_collateralId][_keeper]._totalKSCMinted = _add(
            s_reserves[_collateralId][_keeper]._totalKSCMinted,
            normalizedAmount
        );
    }

    //external view functions
    function getSafetyIndexOfReserve(
        bytes32 _collateralId,
        address _user
    ) external returns (uint256 safetyIndex, uint256 stabilityRate) {
        safetyIndex = _calculateSafetyIndex(_collateralId, _user);
        stabilityRate = s_collaterals[_collateralId].stabilityRate;
    }

    function getCollateralTokenData(
        bytes32 _collateralID
    ) external view returns (uint256 totalDebt, uint256 stabilityRate) {
        totalDebt = s_collaterals[_collateralID].totalDebtOnThisCollateral;
        stabilityRate = s_collaterals[_collateralID].stabilityRate;
    }

    //internal and helper functions
    /**
     * @dev Internal function to check if the caller is authorized.
     * Reverts with HeadStationError_UnAuthorizedOperation if the caller is not authorized.
     */
    function _authenticate() internal view {
        if (!s_authorizedAddresses[msg.sender]) {
            revert HeadStationError_UnAuthorizedOperation();
        }
    }
    function _updateRate(bytes32 _collateralId) internal {
        uint256 oldRate = s_collaterals[_collateralId].stabilityRate;
        uint256 newRate = rateAggregator.calculateStabilityRate(
            _collateralId,
            oldRate
        );
        s_collaterals[_collateralId].stabilityRate = newRate;
        uint256 totalDebtChange = _mul(
            s_collaterals[_collateralId].totalDebtOnThisCollateral,
            _sub(newRate, oldRate)
        );
        s_totalKSCIssued = _add(s_totalKSCIssued, totalDebtChange);
    }

    function _calculateSafetyIndex(
        bytes32 _collateralId,
        address _user
    ) internal returns (uint256 safetyIndex) {
        _updateRate(_collateralId);
        uint256 collateralThreshold = s_collaterals[_collateralId]
            .liquidationThreshold;
        uint256 reserveCollateral = s_reserves[_collateralId][_user]
            ._totalCollateral;
        uint256 reserveNormalizedDebt = s_reserves[_collateralId][_user]
            ._totalKSCMinted;
        uint256 reserveDebt = _mul(
            reserveNormalizedDebt,
            s_collaterals[_collateralId].stabilityRate
        );
        if (reserveDebt <= 0) {
            return type(uint).max;
        }
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_collaterals[_collateralId].priceFeedAddress
        );
        uint256 collateralValueInUSD = priceFeed.getUSDValueForTokenAmount(
            reserveCollateral
        );
        uint256 collateralToThreshold = (collateralValueInUSD *
            collateralThreshold) / THRESHOLD_PRECISION;
        safetyIndex = collateralToThreshold / reserveDebt;
    }

    function _revertIfSafetyIndexIsBroken(
        bytes32 _collateralId,
        address _user
    ) internal {
        uint safetyIndex = _calculateSafetyIndex(_collateralId, _user);
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
