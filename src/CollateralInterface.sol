// SPDX-License-Identifier: MIT
/**
 * @title CollateralInterface
 * @author Karthikeya Gundumogula
 * @notice This contract is used to handle deposits and withdrawl of the KelCoin liquidity
 */
pragma solidity 0.8.19;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {EnumerableMap} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/utils/structs/EnumerableMap.sol";

contract CollateralInterface is CCIPReceiver, OwnerIsCreator {
    using EnumerableMap for EnumerableMap.Bytes32ToUintMap;

    error CollateralInterfaceError_InsufficientBalance();
    error CollateralInterfaceError_NothingToWithdraw();
    error CollateralInterfaceError_FailedToWithdrawEth(address owner, address target, uint256 value);
    error CollateralInterfaceError_SenderNotAllowed(address sender);
    error CollateralInterfaceError_InvalidReceiverAddress();
    error CollateralInterfaceError_OnlySelf();

    enum ErrorCode {
        RESOLVED,
        FAILED
    }

    struct FailedMessage {
        bytes32 messageId;
        ErrorCode errorCode;
    }

    struct Transaction {
        string txType;
        address user;
        uint256 amount;
    }

    IERC20 private s_linkToken;
    IERC20 private s_collateralToken;

    address public s_receiverContract;
    uint64 s_destinationChainSelector;
    string private constant WITHDRAW = "W";
    string private constant DEPOSIT = "D";
    string private constant DEPOSITSUCCESS = "DS";
    string private constant DEPOSITFAIL = "DF";
    string private constant WITHDRAWSUCCESS = "WS";
    string private constant WITHDRAWFAIL = "WF";

    mapping(address user => uint256 balance) private s_userCollaterals;
    mapping(address user => uint256 amount) private s_failedDeposits;
    mapping(bytes32 messageId => Transaction tx) private s_transactions;
    EnumerableMap.Bytes32ToUintMap internal s_failedMessages;

    event MessageSent(
        bytes32 indexed messageId,
        address receiver,
        uint256 amount,
        address feeToken,
        uint256 fees
    );

    event depositSuccess(address user, uint256 amount);
    event depositFailed(address user, uint256 amount);
    event withdrawSuccess(address user, uint256 amount);
    event withdrawFailed(address user, uint256 amount);
    event MessageFailed(bytes32 indexed messageId, bytes reason);

    constructor(address _router, address _link, address _collateral) CCIPReceiver(_router) {
        s_linkToken = IERC20(_link);
        s_collateralToken = IERC20(_collateral);
    }

    modifier onlySelf() {
        if (msg.sender != address(this)) revert CollateralInterfaceError_OnlySelf();
        _;
    }

    function depositCollateral(
        uint256 _amount
    ) external onlyOwner returns (bytes32 messageId) {
        if(s_collateralToken.balanceOf(msg.sender) < _amount){
            revert CollateralInterfaceError_InsufficientBalance();
        }
        s_collateralToken.transfer(address(this),_amount);
        uint256 fee;
        (messageId,fee) = _sendCCIPMessage(msg.sender,_amount,DEPOSIT);
        emit MessageSent(
            messageId,
            s_receiverContract,
            _amount,
            address(s_linkToken),
            fee
        );
        return messageId;
    }

    function withdrawCollateral(
        uint256 _amount
    ) external onlyOwner returns (bytes32 messageId) {
        if(s_userCollaterals[msg.sender]< _amount){
            revert CollateralInterfaceError_InsufficientBalance();
        }
        s_collateralToken.transfer(address(this),_amount);
        uint256 fee;
        (messageId,fee) = _sendCCIPMessage(msg.sender,_amount,WITHDRAW);
        emit MessageSent(
            messageId,
            s_receiverContract,
            _amount,
            address(s_linkToken),
            fee
        );
        return messageId;
    }

    function getFailedMessages(
        uint256 offset,
        uint256 limit
    ) external view returns (FailedMessage[] memory) {
        uint256 length = s_failedMessages.length();
        uint256 returnLength = (offset + limit > length)
            ? length - offset
            : limit;
        FailedMessage[] memory failedMessages = new FailedMessage[](
            returnLength
        );

        for (uint256 i = 0; i < returnLength; i++) {
            (bytes32 messageId, uint256 errorCode) = s_failedMessages.at(
                offset + i
            );
            failedMessages[i] = FailedMessage(messageId, ErrorCode(errorCode));
        }
        return failedMessages;
    }

    function ccipReceive(
        Client.Any2EVMMessage calldata any2EvmMessage
    ) external override onlyRouter {
        try this.processMessage(any2EvmMessage) {} catch (bytes memory err) {
            s_failedMessages.set(
                any2EvmMessage.messageId,
                uint256(ErrorCode.FAILED)
            );
            emit MessageFailed(any2EvmMessage.messageId, err);
            return;
        }
    }

    function processMessage(
        Client.Any2EVMMessage calldata any2EvmMessage
    ) external onlySelf {
        _ccipReceive(any2EvmMessage);
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        (string memory response, bytes32 messageId) = abi.decode(any2EvmMessage.data,(string,bytes32));
            Transaction memory txn = s_transactions[messageId];
        if(keccak256(abi.encodePacked(response)) == keccak256(abi.encodePacked(DEPOSITSUCCESS))){
            s_userCollaterals[txn.user]+= txn.amount;
            emit depositSuccess(txn.user,txn.amount);
        }
        if(keccak256(abi.encodePacked(response)) == keccak256(abi.encodePacked(DEPOSITFAIL))) {
            s_failedDeposits[txn.user]+= txn.amount;
            emit depositFailed(txn.user,txn.amount);
        }
        if(keccak256(abi.encodePacked(response)) == keccak256(abi.encodePacked(WITHDRAWSUCCESS))){
            s_collateralToken.transferFrom(address(this),txn.user,txn.amount);
            emit withdrawSuccess(txn.user,txn.amount);
        }
        if(keccak256(abi.encodePacked(response)) == keccak256(abi.encodePacked(WITHDRAWFAIL))){
            emit withdrawFailed(txn.user,txn.amount);
        }
    }

    function _sendCCIPMessage(
        address _user,
        uint256 _amount,
        string memory _txType
    ) internal returns (bytes32 messageId,uint256 fees) {
        Client.EVM2AnyMessage memory evm2AnyMessage=  Client.EVM2AnyMessage({
            receiver: abi.encode(s_receiverContract),
            data: abi.encode(_txType, _user, _amount),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 200_000})
            ),
            feeToken: address(s_linkToken)
        });
        IRouterClient router = IRouterClient(this.getRouter());
         fees = router.getFee(
            s_destinationChainSelector,
            evm2AnyMessage
        );

        if (fees > s_linkToken.balanceOf(address(this)))
            revert CollateralInterfaceError_InsufficientBalance();
        s_linkToken.approve(address(router), fees);
        messageId = router.ccipSend(s_destinationChainSelector, evm2AnyMessage);
    }

    receive() external payable {}

    function withdraw(address _beneficiary) public onlyOwner {
        uint256 amount = address(this).balance;
        if (amount == 0) revert CollateralInterfaceError_NothingToWithdraw();
        (bool sent, ) = _beneficiary.call{value: amount}("");
        if (!sent) revert CollateralInterfaceError_FailedToWithdrawEth(msg.sender, _beneficiary, amount);
    }

    function withdrawFailedDeposits() external {
        uint256 amount = s_failedDeposits[msg.sender];
        if(amount<= 0) {
            revert CollateralInterfaceError_NothingToWithdraw();
        }
        s_collateralToken.transfer(msg.sender,amount);
    }
}
