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

    function burn(address _account, uint256 _id, uint256 _amount) external;

    function burnBatch(
        address _fromAccount,
        uint256[] memory _ids,
        uint256[] memory _amounts
    ) external;

    function safeTransferFrom(
        address _src,
        address _dst,
        uint256 _id,
        uint256 _amount
    ) external;

    function getBalnce(
        address _user,
        uint256 _assetId
    ) external view returns (uint256 balance);
}

interface IKelStableCoin {
    function getBalance(
        address _spender
    ) external view returns (uint256 balance);

    function sendTokens(
        address _sender,
        address _receiver,
        uint256 _amout
    ) external returns (bool success);
}

interface IGameStation {
    function updateGameOwner(uint256 _gameId, address _newOwner) external;

    function mintAssets(
        uint256 _gameId,
        uint256 _assetId,
        uint256 _amount,
        uint256 _price
    ) external;

    function transferAssets(
        uint256 _gameId,
        uint256 _assetId,
        uint256 _amount,
        address _palyer
    ) external;

    function depositKSC(uint256 _gameId, uint _amount) external;
}

contract AssetWarehouse {
    error AssetWarehouseError_OnlyGameOwner();

    uint256 public s_NftIds;
    IAssets private s_assets;
    IKelStableCoin private s_kelStableCoin;
    IGameStation private s_gameStation;

    mapping(uint256 _gameId => address _owner) private s_gameIdToOwner;
    mapping(uint256 _gameId => uint _gamePassId) private s_gameIdToPassId;

    modifier onlyGameOwner(uint256 _gameId) {
        if (s_gameIdToOwner[_gameId] != msg.sender) {
            revert AssetWarehouseError_OnlyGameOwner();
        }
        _;
    }

    constructor(address _assets, address _gameStation, address _kelCoin) {
        s_assets = IAssets(_assets);
        s_gameStation = IGameStation(_gameStation);
        s_kelStableCoin = IKelStableCoin(_kelCoin);
    }

    function createGame(string memory Uri) external {
        uint256 id = ++s_NftIds;
        s_assets.mint(msg.sender, id, 1, Uri);
        s_gameIdToOwner[id] = msg.sender;
        s_gameStation.updateGameOwner(id, msg.sender);
    }

    function depositKelCoin(
        uint256 _gameId,
        uint256 _amount
    ) external onlyGameOwner(_gameId) {
        s_kelStableCoin.sendTokens(msg.sender, address(this), _amount);
        s_gameStation.depositKSC(_gameId, _amount);
    }

    function mintNewAssets(
        uint256 _gameId,
        uint256 _amount,
        uint256 _price,
        string memory Uri
    ) external onlyGameOwner(_gameId) {
        uint256 id = ++s_NftIds;
        s_assets.mint(msg.sender, id, _amount, Uri);
        s_gameStation.mintAssets(_gameId, id, _amount, _price);
    }

    function transferAssets(
        uint256 _gameId,
        address _receiver,
        uint256 _assetId,
        uint256 _amount
    ) external onlyGameOwner(_gameId) {
        s_assets.safeTransferFrom(msg.sender, _receiver, _assetId, _amount);
        s_gameStation.transferAssets(_gameId, _assetId, _amount, _receiver);
    }

    function burnAssets(uint256 _gameId) external onlyGameOwner(_gameId) {}
}
