//SPDX-License-Identifier: MIT

/**
 * @title CollateralTeller
 * @author Karthikeya Gundumogula
 * @notice This contract is the receiver end of the CCIP interface that deposits collateral
 * @dev This contract updates the Users collateral balnce in the HeadStation contract
 * after receiving the msg from the sender contract
 */
pragma solidity ^0.8.20;

interface HeadStation {
    function depositCollateral(
        bytes32 _collateralType,
        uint256 _amount,
        address _user
    ) external;

    function withdrawCollateral(
        bytes32 _collateralType,
        uint256 _amount,
        address _user
    ) external;

    function depositKSC(
        bytes32 _collateralType,
        uint256 _amount,
        address _user
    ) external;

    function withdrawKSC(
        bytes32 _collateralType,
        uint256 _amount,
        address _user
    ) external;
}

contract CollateralTeller {
    error CollateralTellerError_UnAuthorizedOperation();
    error CollateralTellerError_PausedWithDrawls();
    error CollateralTellerError_AmountLessThanZero();
    error CollateralTellerError_CollateralTransferFailed();
    error CollateralTellerError_AmountOverFlown();

    uint256 private constant HEADSTATIONPRECISION = 10 ** 27;
    bytes32 private s_collateralType;
    HeadStation public s_headStation;
    uint256 private s_collateralDecimals;
    bool public s_status;
    mapping(address user => bool authorized) public s_authorizedAddresses;

    //--Events--//
    event AuthorizedAddressAdded(address user);
    event AuthorizedAddressRemoved(address user);
    event CollateralTokenDeposited(address user, uint amount);
    event CollateralTokenWithdrawn(address user, uint amount);
    event StausUpdated(bool status);

    constructor(
        address _headStation,
        bytes32 _collateralType
    ) {
        s_authorizedAddresses[msg.sender] = true;
        s_status = true;
        s_headStation = HeadStation(_headStation);
        s_collateralType = _collateralType;
        emit AuthorizedAddressAdded(msg.sender);
    }

    //--Authorization & Adminstration--//
    modifier authenticate() {
        if (s_authorizedAddresses[msg.sender] != true) {
            revert CollateralTellerError_UnAuthorizedOperation();
        }
        _;
    }
    function addAuthorizedAddress(address user) external authenticate {
        s_authorizedAddresses[user] = true;
        emit AuthorizedAddressAdded(user);
    }
    function removeAuthorizedAddresses(address user) external authenticate {
        s_authorizedAddresses[user] = true;
        emit AuthorizedAddressRemoved(user);
    }
    function changeStatus() external authenticate {
        s_status = !s_status;
        emit StausUpdated(s_status);
    }

    //--Deposit & Withdraw Collateral Token--//
    function depositCollateral(address _user, uint _amount) external authenticate{
        if (s_status == false) {
            revert CollateralTellerError_PausedWithDrawls();
        }
        if (int(_amount) < 0) {
            revert CollateralTellerError_AmountLessThanZero();
        }
        s_headStation.depositCollateral(s_collateralType, _amount, _user);
        emit CollateralTokenDeposited(_user, _amount);
    }

    function withdrawCollateral(address _user, uint _amount) external {
        if (_amount > type(uint256).max) {
            revert CollateralTellerError_AmountOverFlown();
        }
        s_headStation.withdrawCollateral(s_collateralType, _amount, _user);
        emit CollateralTokenWithdrawn(_user, _amount);
    }
}
