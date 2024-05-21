//SPDX-License-Identifier: MIT

/**
 * @title Liquidation Station
 * @author Karthikeya Gundumogula
 * @notice this contract is called by the keepers to liquidate a under-collateralized reserve
 *  this again calls the Auction house to perform auction
 */
pragma solidity ^0.8.20;

interface IHeadStation {
    function getReserves(
        bytes32 id,
        address user
    ) external view returns (uint256 collateral, uint256 debt);

    function getSafetyIndex(
        bytes32 id,
        address user
    ) external view returns (uint256 safetyIndex);
}

interface IAuctionHouse {
    function startAuction(
        uint256 _collateralAmount,
        uint256 _debtAmount,
        address _reserveOwner,
        address _keeper
    ) external;
}

contract LiquidationStation {
    error LiquidationStationError_UnAuthorizedOperation();
    error LiquidationStationError_UnRecognizedOperation();
    error LiquidationStationError_LiquidationChargeUnderFlow();
    error  LiquidationStationError_ReserveIsHealthy();

    struct Collateral {
        address auctionHouse;
        uint256 liquidationCharge;
        uint256 maxKSCLimitOnThisCollateral;
        uint256 kscNeededOnThisCollateal; //debt+fees(liquidation charges)
    }

    uint256 private constant TOKEN_PRECISION = 10e18;
    IHeadStation private immutable s_headStation;
    mapping(address => bool) public s_authorizedAddresses;
    uint256 private maxKSCAllowed; //protocol level
    uint256 private totalKSCDebt; //protocol level
    bool public status;
    mapping(bytes32 collateralId => Collateral collateral)
        private s_collaterals;

    //--events--//
    event authorizedAddressAdded(address user);
    event authorizedAddressRemoved(address user);
    event statusUpdated(bool status);
    event feildUpdated(bytes32 indexed what, uint256 data);
    event feildUpdated(bytes32 indexed what, address data);
    event feildUpdated(
        bytes32 indexed collateralID,
        bytes32 indexed what,
        uint256 data
    );
    event feildUpdated(
        bytes32 indexed collateralID,
        bytes32 indexed what,
        address auctionHouse
    );

    constructor(address _headStationAddress) {
        s_headStation = IHeadStation(_headStationAddress);
        status = true;
        s_authorizedAddresses[msg.sender] = true;
        emit statusUpdated(status);
        emit authorizedAddressAdded(msg.sender);
    }

    //--Authorization & Adminstration--//
    modifier authenticate() {
        if (s_authorizedAddresses[msg.sender] != true) {
            revert LiquidationStationError_UnAuthorizedOperation();
        }
        _;
    }

    function addAuthorizedAddress(address _user) external authenticate {
        s_authorizedAddresses[_user] = true;
        emit authorizedAddressAdded(_user);
    }

    function removeAuthorizedAddress(address _user) external authenticate {
        s_authorizedAddresses[_user] = true;
        emit authorizedAddressRemoved(_user);
    }

    function update(bytes32 _feild, uint256 _value) external authenticate {
        if (_feild == "maxKSCAllowed") {
            maxKSCAllowed = _value;
        } else {
            revert LiquidationStationError_UnRecognizedOperation();
        }
    }

    function update(
        bytes32 _collateralId,
        bytes32 _feild,
        uint256 _value
    ) external authenticate {
        if (_feild == "liquidationCharge") {
            if (_value < TOKEN_PRECISION) {
                revert LiquidationStationError_LiquidationChargeUnderFlow();
            }
            s_collaterals[_collateralId].liquidationCharge = _value;
        } else if (_feild == "maxKSCLimit") {
            s_collaterals[_collateralId].maxKSCLimitOnThisCollateral = _value;
        } else {
            revert LiquidationStationError_UnRecognizedOperation();
        }
        emit feildUpdated(_collateralId, _feild, _value);
    }

    function liquidateReserve(bytes32 _collateralId, address _user) external {
        uint256 safetyIndex = s_headStation.getSafetyIndex(_collateralId,_user);
        if(safetyIndex > 1){
            revert LiquidationStationError_ReserveIsHealthy();
        }
    }

    //--external view functions--//
    function getLiquidationChargeForCollateral(
        bytes32 _collateralID
    ) external view returns (uint256 charge) {
        charge = s_collaterals[_collateralID].liquidationCharge;
    }

}
