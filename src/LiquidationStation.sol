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

    function getSafetyIndexOfReserve(
        bytes32 _collateralId,
        address _user
    ) external returns (uint256 safetyIndex, uint256 stabilityRate);

    function confiscateReserve(
        bytes32 _collateralId,
        address _reserveOwner,
        int256 _collateral,
        int256 _debtKSC
    ) external;
}

interface IAuctionHouse {
    function startAuction(
        bytes32 _collateralId,
        uint256 _collateralAmount,
        uint256 _debtAmount,
        address _reserveOwner,
        address _keeper
    ) external;
}

contract LiquidationStation {
    error LiquidationStationError_UnAuthorizedOperation();
    error LiquidationStationError_MaxDebtLimitExceeding();
    error LiquidationStationError_UnRecognizedOperation();
    error LiquidationStationError_liquidationPenaltyUnderFlow();
    error LiquidationStationError_ReserveIsHealthy();

    struct Collateral {
        address auctionHouse;
        uint256 liquidationPenalty;
        uint256 maxDebtLimitOnThisCollateral;
        uint256 kscNeededOnThisCollateal; //debt+fees(liquidation charges)
    }

    uint256 private constant TOKEN_PRECISION = 10e18;
    IHeadStation private immutable s_headStation;
    IAuctionHouse private s_auctionHouse;
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

    constructor(address _headStationAddress, address _auctionHouse) {
        s_headStation = IHeadStation(_headStationAddress);
        status = true;
        s_authorizedAddresses[msg.sender] = true;
        s_auctionHouse = IAuctionHouse(_auctionHouse);
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
        if (_feild == "liquidationPenalty") {
            if (_value < TOKEN_PRECISION) {
                revert LiquidationStationError_liquidationPenaltyUnderFlow();
            }
            s_collaterals[_collateralId].liquidationPenalty = _value;
        } else if (_feild == "maxKSCLimit") {
            s_collaterals[_collateralId].maxDebtLimitOnThisCollateral = _value;
        } else {
            revert LiquidationStationError_UnRecognizedOperation();
        }
        emit feildUpdated(_collateralId, _feild, _value);
    }

    function liquidateReserve(bytes32 _collateralId, address _user) external {
        (uint256 safetyIndex, uint256 stabilityRate) = s_headStation
            .getSafetyIndexOfReserve(_collateralId, _user);
        if (safetyIndex > 1) {
            revert LiquidationStationError_ReserveIsHealthy();
        }
        (uint collateral, uint normalizedDebt) = s_headStation.getReserves(
            _collateralId,
            _user
        );
        uint256 liquidationPenalty = s_collaterals[_collateralId]
            .liquidationPenalty;
        uint debt = normalizedDebt * stabilityRate;
        debt += (debt * liquidationPenalty);
        uint collateralDebt = debt +
            s_collaterals[_collateralId].kscNeededOnThisCollateal;
        uint systemDebt = totalKSCDebt + debt;
        if (
            collateralDebt >
            s_collaterals[_collateralId].maxDebtLimitOnThisCollateral ||
            systemDebt > maxKSCAllowed
        ) {
            revert LiquidationStationError_MaxDebtLimitExceeding();
        }
        s_headStation.confiscateReserve(
            _collateralId,
            _user,
            int(collateral),
            int(debt)
        );
        s_auctionHouse.startAuction(
            _collateralId,
            collateral,
            debt,
            _user,
            msg.sender
        );
    }

    //--external view functions--//
    function getliquidationPenaltyForCollateral(
        bytes32 _collateralID
    ) external view returns (uint256 charge) {
        charge = s_collaterals[_collateralID].liquidationPenalty;
    }
}
