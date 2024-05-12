//SPDX-License-Identifier: MIT

/**
 * @title Kel StableCoin
 * @author Karthikeya Gundumogula
 * @notice Authorization is required to mint, add authorized addresses and remove authorized addresses from the contract.
 * @dev This contract is an External Token facing users this token and internal balances maintained by the HeadStation contract is connected by the 
 */
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract KelCoin is ERC20 {
    error KelError_UnAuthorizedMinter();

    constructor() ERC20("Kel StableCoin", "KEL") {}

    mapping(address => bool) private s_authorizedAddresses;

    modifier authenticate() {
        if (s_authorizedAddresses[msg.sender] == false) {
            revert KelError_UnAuthorizedMinter();
        }
        _;
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        return super.transfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }

    function addAuthorizedAddress(address _user) external authenticate {
        s_authorizedAddresses[_user] = true;
    }

    function removeAuthorizedAddress(address _user) external authenticate {
        s_authorizedAddresses[_user] = false;
    }

    function mint(address account, uint256 amount) external authenticate {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external authenticate {
        _burn(account, amount);
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        return super.approve(spender, amount);
    }
}
