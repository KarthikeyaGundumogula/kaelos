//SPDX-License-Identifier: MIT
/**
 * @title Assets
 * @author Karthikeya
 * @notice This Contract is the ERC1155 NFT contract where the assets are Minted
 */

pragma solidity ^0.8.20;

import {ERC1155, ERC1155URIStorage} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";

contract Assets is ERC1155URIStorage {
    error AssetWarehouseError_UnAuthorizedAddress();

    mapping(address user => bool status) private s_authorizedAddresses;

    constructor() ERC1155("") {}

    //--Authorization--//
    modifier authenticate() {
        if (s_authorizedAddresses[msg.sender] != true) {
            revert AssetWarehouseError_UnAuthorizedAddress();
        }
        _;
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        string memory URI
    ) external authenticate {
        _mint(account, id, amount, "");
        _setURI(id, URI);
    }

    function mintBatch(
        address _receiver,
        uint256[] memory _ids,
        uint256[] memory _amounts
    ) external authenticate {
        _mintBatch(_receiver, _ids, _amounts, "");
    }

    function burn(
        address _account,
        uint256 _id,
        uint256 _amount
    ) external authenticate {
        _burn(_account, _id, _amount);
    }

    function burnBatch(
        address _fromAccount,
        uint256[] memory _ids,
        uint256[] memory _amounts
    ) external authenticate {
        _burnBatch(_fromAccount, _ids, _amounts);
    }

    function safeTransferFrom(
        address _src,
        address _dst,
        uint256 _id,
        uint256 _amount
    ) external {
        _safeTransferFrom(_src, _dst, _id, _amount, "");
    }

    function getBalnce(
        address _user,
        uint256 _assetId
    ) external view returns (uint256 balance) {
        balance = balanceOf(_user, _assetId);
    }
}
