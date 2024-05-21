//SPDX-License-Identifier: MIT

/**
 * @title TellerStation
 * @author Karthikeya GUndumogula
 * @notice this contract manages the connection between the HeadStation Balances and the External Kel Coin
 */
pragma solidity ^0.8.20;

interface Collateral {
    function decimals() external view returns (uint);

    function transfer(address, uint) external returns (bool);

    function transferFrom(address, address, uint) external returns (bool);
}

interface KelCoin {
    function mint(address, uint) external;

    function burn(address, uint) external;
}

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

/**
 * @notice this Contract handles the deposit and witdrawl of Kel Coin
 */
contract KelCoinTeller {
    error KelTellerStationError_UnAuthorizedOperation();
    error KelTellerStationError_PausedWithdrawls();

    uint256 private constant HEADSTATIONPRESICION = 10 ** 27;
    KelCoin public s_kelCoin;
    HeadStation public s_headStation;
    bool public s_status;
    mapping(address user => bool authorized) private s_authorizedAddresses;

    //--Events--//
    event AuthorizedAddressAdded(address user);
    event AuthorizedAddressRemoved(address user);
    event KelCoinDeposited(address user, uint amount);
    event KelCoinWithdrawn(address user, uint amount);
    event StausUpdated(bool status);

    constructor(address _kelCoin, address _headStation) {
        s_kelCoin = KelCoin(_kelCoin);
        s_headStation = HeadStation(_headStation);
        s_authorizedAddresses[msg.sender] = true;
        emit AuthorizedAddressAdded(msg.sender);
    }

    //--Internal Helpers--//
    function multiply(uint x, uint y) internal pure returns (uint z) {
        z = x * y;
        require(y == 0 || z / y == x);
    }

    //--Authorization & Administration--//
    modifier authorize() {
        if (s_authorizedAddresses[msg.sender] != true) {
            revert KelTellerStationError_UnAuthorizedOperation();
        }
        _;
    }

    function addAuthorizedAddress(address user) external authorize {
        s_authorizedAddresses[user] = true;
        emit AuthorizedAddressAdded(user);
    }

    function removeAuthorizedAddress(address user) external authorize {
        s_authorizedAddresses[user] = false;
        emit AuthorizedAddressRemoved(user);
    }

    function changeStatus() external authorize {
        s_status = !s_status;
        emit StausUpdated(s_status);
    }

    //--Deposit & Withdraw KelCoin--//
    function depositKelCoin(
        address _user,
        uint _amount,
        bytes32 _collateralType
    ) external {
        s_headStation.depositKSC(_collateralType, _amount, _user);
        s_kelCoin.burn(msg.sender, _amount);
        emit KelCoinDeposited(_user, _amount);
    }

    function withdrawKelCoin(
        address _user,
        uint _amount,
        bytes32 _collateralType
    ) external {
        if (s_status == false) {
            revert KelTellerStationError_PausedWithdrawls();
        }
        s_headStation.withdrawKSC(_collateralType, _amount, _user);
        s_kelCoin.mint(msg.sender, _amount);
        emit KelCoinWithdrawn(_user, _amount);
    }
}

contract CollateralTeller {
    error CollateralTellerError_UnAuthorizedOperation();
    error CollateralTellerError_PausedWithDrawls();
    error CollateralTellerError_AmountLessThanZero();
    error CollateralTellerError_CollateralTransferFailed();
    error CollateralTellerError_AmountOverFlown();

    uint256 private constant HEADSTATIONPRECISION = 10 ** 27;
    Collateral public collateralToken;
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
        bytes32 _collateralType,
        address _collateralAddress
    ) {
        s_authorizedAddresses[msg.sender] = true;
        s_status = true;
        s_headStation = HeadStation(_headStation);
        s_collateralType = _collateralType;
        collateralToken = Collateral(_collateralAddress);
        s_collateralDecimals = collateralToken.decimals();
        emit AuthorizedAddressAdded(msg.sender);
    }

    //--Authorization & Adminstration--//
    modifier authorize() {
        if (s_authorizedAddresses[msg.sender] != true) {
            revert CollateralTellerError_UnAuthorizedOperation();
        }
        _;
    }

    function addAuthorizedAddress(address user) external authorize {
        s_authorizedAddresses[user] = true;
        emit AuthorizedAddressAdded(user);
    }

    function removeAuthorizedAddresses(address user) external authorize {
        s_authorizedAddresses[user] = true;
        emit AuthorizedAddressRemoved(user);
    }

    function changeStatus() external authorize {
        s_status = !s_status;
        emit StausUpdated(s_status);
    }

    //--Deposit & Withdraw Collateral Token--//
    function depositCollateral(address _user, uint _amount) external {
        if (s_status == false) {
            revert CollateralTellerError_PausedWithDrawls();
        }
        if (int(_amount) < 0) {
            revert CollateralTellerError_AmountLessThanZero();
        }
        s_headStation.depositCollateral(s_collateralType, _amount, _user);
        bool success = collateralToken.transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        if (!success) {
            revert CollateralTellerError_CollateralTransferFailed();
        }
        emit CollateralTokenDeposited(_user, _amount);
    }

    function withdrawCollateral(address _user, uint _amount) external {
        if (_amount > type(uint256).max) {
            revert CollateralTellerError_AmountOverFlown();
        }
        s_headStation.withdrawCollateral(s_collateralType, _amount, _user);
        bool success = collateralToken.transfer(_user, _amount);
        if (!success) {
            revert CollateralTellerError_CollateralTransferFailed();
        }
        emit CollateralTokenWithdrawn(_user, _amount);
    }
}
