//SPDX-License-Identifier: MIT

/**
 * @title SolvencyStation
 * @author Karthikeya Gundumogula
 * @notice This contract handles the current prices of Collaterals and calculates the Safety Index for the given Reserve
 */

pragma solidity ^0.8.20;

contract SolvencyStation {

  struct Collateral {
    address priceFeed;
    uint256 safetyIndex;
  }

  mapping(bytes32 collateralType=> Collateral data) public collateralTokens;
  

}