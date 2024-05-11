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

contract KelTellerStation {
    error KelTellerStationError_UnAuthorizedOperation();

    KelCoin public kelCoin;
    HeadStation public headStation;
    mapping(address user => bool authorized) private s_authorizedAddresses;

    constructor(address _kelCoin, address _headStation) {
        kelCoin = KelCoin(_kelCoin);
        headStation = HeadStation(_headStation);
        s_authorizedAddresses[msg.sender] = true;
    }

    //--Authorization--//

    modifier authorize() {
        if (s_authorizedAddresses[msg.sender] != true) {
            revert KelTellerStationError_UnAuthorizedOperation();
        }
        _;
    }
    function addAuthorizedAddress(address user) external authorize {
        s_authorizedAddresses[user] = true;
    }
}
