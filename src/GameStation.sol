//SPDX-License-Identifier: MIT

/**
 * @title GameStation
 * @author Karthikeya Gundumogula
 * @notice This Contract tracks the Game Vaults and the Asset Balances of the Games and Gamers
 */

pragma solidity ^0.8.20;

contract GameStation {
    error GameStationError_UnAuthorizedAddress();
    error GameStationError_InvalidAssetAmount();
    error GameStationError_AssetNotFound();
    error GameStationError_ZeroAddressGameOwner();
    error GameStationError_SafetyIndexBroken();

    struct GameTreasury {
        uint256 totalKSCBalance;
        uint256 issuedAssetsValue;
        address owner;
        uint256[] assetIds;
    }
    struct Asset {
        uint256 price;
        uint256 gameId;
    }
    uint256 private s_liquidationThreshold;
    mapping(address user => bool access) private s_authorizedAddresses;
    mapping(uint256 gameId => GameTreasury treasury) private s_gameTreasuries;
    mapping(uint256 gameId => mapping(address user => uint256[] assetIds))
        private s_gamePlayerAssetIds;
    mapping(uint256 assetId => Asset asset) private s_assets;
    mapping(address user => mapping(uint256 assetId => uint256 holdingAmount))
        private s_userAssets;

    //--Events--//
    event authorizedAddressAdded(address user);
    event authorizedAddressRemoved(address user);

    constructor() {
        s_authorizedAddresses[msg.sender] = true;
    }

    //--Authorization and Adminstration--//
    modifier authenticate() {
        if (s_authorizedAddresses[msg.sender] != true) {
            revert GameStationError_UnAuthorizedAddress();
        }
        _;
    }

    function addAuthorizedAddress(address _user) external authenticate {
        s_authorizedAddresses[_user] = true;
        emit authorizedAddressAdded(_user);
    }

    function removeAuthorizedAddress(address _user) external authenticate {
        s_authorizedAddresses[_user] = false;
        emit authorizedAddressRemoved(_user);
    }

    function updateLiquidationThreshold(
        uint256 _newThreshold
    ) external authenticate {
        s_liquidationThreshold = _newThreshold;
    }

    function updateGameOwner(
        uint256 _gameId,
        address _newOwner
    ) external authenticate {
        s_gameTreasuries[_gameId].owner = _newOwner;
    }

    function depositKSC(
        uint256 _gameId,
        uint256 _amount
    ) external authenticate {
        s_gameTreasuries[_gameId].totalKSCBalance += _amount;
    }

    function withdrawKSC(
        uint256 _gameId,
        uint256 _amount
    ) external authenticate {
        s_gameTreasuries[_gameId].totalKSCBalance += _amount;
        _revertIfSafetyIndexBroken(_gameId);
    }

    function liquidatePlayer(
        address _player,
        uint256 _gameId
    ) external returns (uint256 liquidationAmount) {
        s_userAssets = 
    }

    function mintAssets(
        uint256 _gameId,
        uint256 _assetId,
        uint256 _amount,
        uint256 _price
    ) external authenticate {
        GameTreasury storage game = s_gameTreasuries[_gameId];
        if (game.owner == address(0)) {
            revert GameStationError_ZeroAddressGameOwner();
        }
        game.assetIds.push(_assetId);
        uint256 assetValue = _amount * s_assets[_assetId].price;
        game.issuedAssetsValue += assetValue;
        s_assets[_assetId].price = _price;
        s_assets[_assetId].gameId = _gameId;
        s_userAssets[game.owner][_assetId] += _amount;
        _revertIfSafetyIndexBroken(_gameId);
    }

    function mintExistingAssets(
        uint256 _gameId,
        uint256 _assetId,
        uint256 _amount
    ) external {
        address owner = s_gameTreasuries[_gameId].owner;
        if (owner == address(0)) {
            revert GameStationError_ZeroAddressGameOwner();
        }
        s_userAssets[owner][_assetId] += _amount;
        s_gameTreasuries[_gameId].issuedAssetsValue +=
            _amount *
            s_assets[_assetId].price;
        _revertIfSafetyIndexBroken(_gameId);
    }

    function transferAssets(
        uint256 _gameId,
        uint256 _assetId,
        uint256 _amount,
        address _palyer
    ) external authenticate {
        GameTreasury storage game = s_gameTreasuries[_gameId];
        if (game.owner == address(0)) {
            revert GameStationError_ZeroAddressGameOwner();
        }
        if (s_userAssets[game.owner][_assetId] == 0) {
            revert GameStationError_AssetNotFound();
        }
        if (s_userAssets[game.owner][_assetId] < _amount || _amount < 0) {
            revert GameStationError_InvalidAssetAmount();
        }
        if (s_userAssets[_palyer][_assetId] == 0) {
            s_gamePlayerAssetIds[_gameId][_palyer].push(_assetId);
        }
        s_userAssets[_palyer][_assetId] += _amount;
        s_userAssets[game.owner][_assetId] -= _amount;
    }

    function burnAssets(
        uint256 _gameId,
        uint256 _assetId,
        uint256 _amount
    ) external {
        uint256 burningAssetValue = s_assets[_assetId].price * _amount;
        s_gameTreasuries[_gameId].issuedAssetsValue -= burningAssetValue;
    }

    //--Internal Helper Fucntions--//
    function _revertIfSafetyIndexBroken(uint256 _gameId) internal view {
        uint256 safetyIndex = _calculateSafetyIndex(_gameId);
        if (safetyIndex < 1) {
            revert GameStationError_SafetyIndexBroken();
        }
    }

    function _calculateSafetyIndex(
        uint256 _gameId
    ) internal view returns (uint256 safetyIndex) {
        uint256 kscAmount = s_gameTreasuries[_gameId].totalKSCBalance;
        uint256 issuedAssetsValue = s_gameTreasuries[_gameId].issuedAssetsValue;
        if (issuedAssetsValue == 0) {
            return safetyIndex = type(uint256).max;
        }
        uint256 thresholdAdjustedKscValue = kscAmount * s_liquidationThreshold;
        safetyIndex = thresholdAdjustedKscValue / issuedAssetsValue;
    }
}
