//SPDX-License-Identifier: MIT

/**
 * @title GameAssetStation
 * @author Karthikeya Gundumogula
 * @notice This Contract tracks the Game Vaults and the Asset Balances of the Games and Gamers
 */

pragma solidity ^0.8.20;

contract GameAssetStation {

  struct Game {
    uint256 totalKSCBalance;
    uint256 issuedAssetsValue;
  }
}
