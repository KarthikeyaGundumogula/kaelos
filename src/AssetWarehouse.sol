// SPDX-License-Identifier: MIT

/**
 * @title AssetWarehouse
 * @author Karthikeya Gundumogula
 * @notice Games connect to this contract to mint and Issue Assets
 */

pragma solidity ^0.8.20;

interface IAssets {
    function mint(
        address account,
        uint256 id,
        uint256 amount,
        string memory URI
    ) external;

    function mintBatch(
        address _receiver,
        uint256[] memory _ids,
        uint256[] memory _amounts
    ) external;

    function safeTransferFrom(
        address _src,
        address _dst,
        uint256 _id,
        uint256 _amount
    ) external;
}

contract AssetWarehouse {
  
}
