//SPDX-License-Identifier: MIT
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

    function mintExistingAssets(
        uint256 _gameId,
        uint256 _assetId,
        uint256 _amount
    ) external;

    function depositKSC(uint256 _gameId, uint _amount) external;

    function withdrawKSC(uint256 _gameId, uint256 _amount) external;

    function burnAssets(
        uint256 _gameId,
        uint256 _assetId,
        uint256 _amount
    ) external;

    function liquidatePlayer(
        address _player,
        uint256 _gameId
    ) external returns (uint256 liquidationAmount, uint256[] memory assetIds);
}
