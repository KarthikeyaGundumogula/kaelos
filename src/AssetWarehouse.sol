// SPDX-License-Identifier: MIT

/**
 * @title AssetWarehouse
 * @author Karthikeya Gundumogula
 * @notice Games connect to this contract to mint and Issue Assets
 */

pragma solidity ^0.8.20;

import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {IAssets, IKelStableCoin, IGameStation} from "./interfaces/IAssetWareHouse.sol";

contract AssetWarehouse is ERC1155Holder {
    error AssetWarehouseError_OnlyGameOwner();
    error AssetWarehouseError_AssetIsNotTransferrable();
    error AssetWarehouseError_InsufficientAssetBalance();
    error AssetWarehouseError_InvalidGameAssetId();
    error AssetWarehouseError_InsufficientAssetSuply();
    error AssetWarehouseError_PLayerNotSuspended();

    enum PlayerStatus {
        JOINED,
        SUSPENDED
    }

    struct AssetNFT {
        uint256 totalSupply;
        uint256 currentSupply;
        bool transferrable;
        uint256 gameId;
    }

    struct Game {
        address owner;
        uint256 gamePassId;
        uint256 gamePassCost;
    }

    uint256 public s_NftIds;
    IAssets private s_assets;
    IKelStableCoin private s_kelStableCoin;
    IGameStation private s_gameStation;

    mapping(uint256 gameId => Game game) private s_games;
    mapping(uint256 assetId => AssetNFT asset) private s_assetNFTs;
    mapping(address player => mapping(uint256 gameId => PlayerStatus status))
        private s_playerGameStatus;
    mapping(address player => mapping(uint256 assetId => uint256 amount))
        private s_playerAssetHoldings;

    modifier onlyGameOwner(uint256 _gameId) {
        if (s_games[_gameId].owner != msg.sender) {
            revert AssetWarehouseError_OnlyGameOwner();
        }
        _;
    }

    constructor(address _assets, address _gameStation, address _kelCoin) {
        s_assets = IAssets(_assets);
        s_gameStation = IGameStation(_gameStation);
        s_kelStableCoin = IKelStableCoin(_kelCoin);
    }

    function createGame(string memory Uri, uint256 _price) external {
        uint256 id = ++s_NftIds;
        s_assets.mint(msg.sender, id, 1, Uri);
        s_games[id].owner = msg.sender;
        uint gamePass = ++s_NftIds;
        s_games[id].gamePassCost = _price;
        s_games[id].gamePassId = gamePass;
        s_gameStation.updateGameOwner(id, msg.sender);
    }

    function buyGamePass(uint256 _gameId) external {
        s_kelStableCoin.sendTokens(
            msg.sender,
            address(this),
            s_games[_gameId].gamePassCost
        );
        s_gameStation.depositKSC(_gameId, s_games[_gameId].gamePassCost);
        s_playerGameStatus[msg.sender][_gameId] = PlayerStatus.JOINED;
    }

    function depositKelCoin(
        uint256 _gameId,
        uint256 _amount
    ) external onlyGameOwner(_gameId) {
        s_kelStableCoin.sendTokens(msg.sender, address(this), _amount);
        s_gameStation.depositKSC(_gameId, _amount);
    }

    function withdrawKelCoin(
        uint256 _gameId,
        uint256 _amount
    ) external onlyGameOwner(_gameId) {
        s_gameStation.withdrawKSC(_gameId, _amount);
        s_kelStableCoin.sendTokens(address(this), msg.sender, _amount);
    }

    function mintNewAssets(
        uint256 _gameId,
        uint256 _amount,
        uint256 _price,
        bool _isTransferrable,
        string memory Uri
    ) external onlyGameOwner(_gameId) {
        uint256 id = ++s_NftIds;
        s_assets.mint(msg.sender, id, _amount, Uri);
        s_gameStation.mintAssets(_gameId, id, _amount, _price);
        s_assetNFTs[id].gameId = _gameId;
        s_assetNFTs[id].totalSupply = _amount;
        s_assetNFTs[id].currentSupply = _amount;
        s_assetNFTs[id].transferrable = _isTransferrable;
    }

    function mintExistingAssets(
        uint256 _gameId,
        uint256 _assetId,
        uint256 _amount
    ) external onlyGameOwner(_gameId) {
        if (s_assetNFTs[_assetId].gameId != _gameId) {
            revert AssetWarehouseError_InvalidGameAssetId();
        }
        s_assets.mint((address(this)), _assetId, _amount, "");
        s_gameStation.mintExistingAssets(_gameId, _assetId, _amount);
        s_assetNFTs[_assetId].totalSupply += _amount;
        s_assetNFTs[_assetId].currentSupply += _amount;
    }

    function issueAssets(
        uint256 _gameId,
        address _receiver,
        uint256 _assetId,
        uint256 _amount
    ) external onlyGameOwner(_gameId) {
        if (s_assetNFTs[_assetId].currentSupply < _amount) {
            revert AssetWarehouseError_InsufficientAssetSuply();
        }
        s_assets.safeTransferFrom(address(this), _receiver, _assetId, _amount);
        s_gameStation.transferAssets(_gameId, _assetId, _amount,s_games[_gameId].owner, _receiver);
        s_playerAssetHoldings[_receiver][_assetId] += _amount;
        s_assetNFTs[_assetId].currentSupply -= _amount;
    }

    function transferAssets(uint256 _gameId,address _receiver,uint256 _assetId,uint256 _amount) external {
        if(s_playerAssetHoldings[msg.sender][_gameId] <_amount){
            revert AssetWarehouseError_InsufficientAssetBalance();
        }
        if(s_assetNFTs[_assetId].transferrable != true) {
            revert AssetWarehouseError_AssetIsNotTransferrable();
        }
        s_assets.safeTransferFrom(address(this), _receiver, _assetId, _amount);
        s_gameStation.transferAssets(_gameId, _assetId, _amount,msg.sender, _receiver);
        s_playerAssetHoldings[_receiver][_assetId] += _amount;        
    }

    function burnAssets(
        uint256 _gameId,
        uint256 _assetId,
        uint256 _amount
    ) external onlyGameOwner(_gameId) {
        s_assets.burn(address(this), _assetId, _amount);
        s_gameStation.burnAssets(_gameId, _assetId, _amount);
        s_assetNFTs[_assetId].totalSupply -= _amount;
        s_assetNFTs[_assetId].currentSupply -= _amount;
    }

    function suspendPlayer(
        uint256 _gameId,
        address _player
    ) external onlyGameOwner(_gameId) {
        s_playerGameStatus[_player][_gameId] = PlayerStatus.SUSPENDED;
    }

    function liquidatePLayer(uint256 _gameId) external {
        if(s_playerGameStatus[msg.sender][_gameId] != PlayerStatus.SUSPENDED){
            revert AssetWarehouseError_PLayerNotSuspended();
        }
        (uint256 liquidationAmount, uint256[] memory assetIds) = s_gameStation
            .liquidatePlayer(msg.sender, _gameId);
        uint256 length = assetIds.length - 1;
        uint256[] memory playerAssetHoldings = new uint256[](length);
        for (uint i = 0; i < length; i++) {
            playerAssetHoldings[i] = (
                s_playerAssetHoldings[msg.sender][assetIds[i]]
            );
        }
        s_assets.burnBatch(msg.sender, assetIds, playerAssetHoldings);
        s_assets.burn(msg.sender, s_games[_gameId].gamePassId, 1);
        s_kelStableCoin.sendTokens(
            address(this),
            msg.sender,
            liquidationAmount
        );
        s_playerGameStatus[msg.sender][_gameId] = PlayerStatus.SUSPENDED;
    }

    function getPlayerStatus(address _player,uint256 _gameId) external view returns(PlayerStatus status){
        status = s_playerGameStatus[_player][_gameId];
    }
}
