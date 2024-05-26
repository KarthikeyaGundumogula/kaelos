//SPDX-License-Identifier: MIT

/**
 * @title TellerStation
 * @author Karthikeya GUndumogula
 * @notice this contract manages the connection between the HeadStation Balances and the External Kel Coin
 */
pragma solidity ^0.8.20;

interface IKelCoin {
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
    IKelCoin public s_kelCoin;
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
        s_kelCoin = IKelCoin(_kelCoin);
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

