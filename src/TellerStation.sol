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
    function slip(bytes32, address, int) external;

    function move(address, address, uint) external;
}

/**
 * @notice this Contract handles the deposit and witdrawl of Kel Coin 
 */
contract KelTellerStation {
    error KelTellerStationError_UnAuthorizedOperation();
    error KelTellerStationError_PausedWithdrawls(); 

    uint256 private constant HEADSTATIONPRESICION = 10**27;
    KelCoin public kelCoin;
    HeadStation public headStation;
    bool public status;
    mapping(address user => bool authorized) private s_authorizedAddresses;

    //--Events--//
    event AuthorizedAddressAdded(address user);
    event AuthorizedAddressRemoved(address user);
    event KelCoinDeposited(address user, uint amount);
    event KelCoinWithdrawn(address user, uint amount);
    event StausUpdated(bool status);

    constructor(address _kelCoin, address _headStation) {
        kelCoin = KelCoin(_kelCoin);
        headStation = HeadStation(_headStation);
        s_authorizedAddresses[msg.sender] = true;
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
    }
    function removeAuthorizedAddress(address user) external authorize {
        s_authorizedAddresses[user] = false;
    }
    function changeStatus() external authorize {
        status = !status;
        emit StausUpdated(status);
    }

    //--Deposit or Withdraw Kel Coin--//

    function depositKelCoin(address _user, uint _amount) external {
        headStation.move(address(this), _user, multiply(_amount, HEADSTATIONPRESICION));
        kelCoin.burn(msg.sender, _amount);
        emit KelCoinDeposited(_user, _amount);
    }

    function withdrawKelCoin(address _user, uint _amount) external {
        if(status == false) {
            revert KelTellerStationError_PausedWithdrawls();
        }
        headStation.move(_user, address(this), multiply(_amount, HEADSTATIONPRESICION));
        kelCoin.mint(msg.sender, _amount);
        emit KelCoinWithdrawn(_user, _amount);
    }
}

