//SPDX-License-Identifier: MIT

/**
 * @title CollateralTeller
 * @author Karthikeya Gundumogula
 * @notice This contract is the receiver end of the CCIP interface that deposits collateral
 * @dev This contract updates the Users collateral balance in the HeadStation contract
 * after receiving the msg from the sender contract
 */

pragma solidity 0.8.19;

import {IRouterClient} from "@chainlink/contracts-ccip@1.4.0/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip@1.4.0/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip@1.4.0/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip@1.4.0/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts-ccip@1.4.0/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts-ccip@1.4.0/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";

interface HeadStation {
    function depositCollateral(
        bytes32 _collateralType,
        uint256 _amount,
        address _user
    ) external;

    function withdrawCollateral(
        bytes32 _collateralType,
        uint256 _amount,
        address _user
    ) external;

    function depositKSC(
        bytes32 _collateralType,
        uint256 _amount,
        address _user
    ) external;

    function withdrawKSC(
        bytes32 _collateralType,
        uint256 _amount,
        address _user
    ) external;
}

using SafeERC20 for IERC20;

contract CollateralTeller is CCIPReceiver, OwnerIsCreator {
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);
    error NothingToWithdraw();
    error CollateralTellerError_TransactionAlreadyProcessed();
    error CollateralTellerError_UnAuthorizedOperation();
    error CollateralTellerError_InSufficientBalance();
    error CollateralTellerError_PausedWithDrawls();
    error CollateralTellerError_AmountLessThanZero();
    error CollateralTellerError_CollateralTransferFailed();
    error CollateralTellerError_AmountOverFlown();

    enum TransactionState {
        RECEIVED,
        PROCESSED
    }

    struct Transaction {
        string txType;
        address user;
        uint amount;
        TransactionState state;
    }

    IERC20 private s_linkToken;

    uint256 private constant HEADSTATIONPRECISION = 10 ** 27;
    string private constant WITHDRAW = "W";
    string private constant DEPOSIT = "D";
    string private constant DEPOSITSUCCESS = "DS";
    string private constant DEPOSITFAIL = "DF";
    string private constant WITHDRAWSUCCESS = "WS";
    string private constant WITHDRAWFAIL = "WF";
    address public s_receiverContract;
    uint64 s_destinationChainId;
    bytes32[] private s_pendingTransactionIds;
    bytes32 private s_collateralType;
    HeadStation public s_headStation;
    bool public s_status;
    mapping(bytes32 receivingMessageId => Transaction txn)
        public s_pendingTransactions;

    //--Events--//
    event AuthorizedAddressAdded(address user);
    event AuthorizedAddressRemoved(address user);
    event CollateralTokenDeposited(address user, uint amount);
    event CollateralTokenWithdrawn(address user, uint amount);
    event StausUpdated(bool status);
    event MessageFailed(bytes32 indexed messageId, bytes reason);
    string private s_lastReceivedText;

    event AcknowledgmentSent(
        bytes32 indexed acknowledgingMessageId,
        bytes32 indexed responseMessageId
    );
    event TransactionReceived(
        bytes32 indexed receivingMessageId,
        address user,
        uint256 amount,
        string txType
    );

    constructor(
        address _router,
        address _link,
        address _headStation,
        bytes32 _collateralType
    ) CCIPReceiver(_router) {
        s_linkToken = IERC20(_link);
        s_headStation = HeadStation(_headStation);
        s_collateralType = _collateralType;
    }

    function initRecevingContract(
        address _receiver,
        uint64 _receiverChainId
    ) external onlyOwner {
        s_receiverContract = _receiver;
        s_destinationChainId = _receiverChainId;
    }

    function executePendingTransaction(bytes32 _messageId) external {
        Transaction memory txn = s_pendingTransactions[_messageId];
        if (txn.state == TransactionState.PROCESSED) {
            revert CollateralTellerError_TransactionAlreadyProcessed();
        }
        if (_compareStrings(txn.txType, DEPOSIT)) {
            bool success = _depositCollateral(txn.user, txn.amount);
            if (success) _sendStatus(_messageId, DEPOSITSUCCESS);
            else _sendStatus(_messageId, DEPOSITFAIL);
        } else {
            bool success = _withdrawCollateral(txn.user, txn.amount);
            if (success) _sendStatus(_messageId, WITHDRAWSUCCESS);
            else _sendStatus(_messageId, WITHDRAWFAIL);
        }
    }

    function _sendStatus(
        bytes32 _messageIdToAcknowledge,
        string memory status
    ) private {
        Client.EVM2AnyMessage memory acknowledgment = Client.EVM2AnyMessage({
            receiver: abi.encode(s_receiverContract),
            data: abi.encode(_messageIdToAcknowledge, status),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 200_000})
            ),
            feeToken: address(s_linkToken)
        });
        IRouterClient router = IRouterClient(this.getRouter());

        uint256 fees = router.getFee(s_destinationChainId, acknowledgment);

        if (fees > s_linkToken.balanceOf(address(this))) {
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);
        }
        s_linkToken.approve(address(router), fees);

        bytes32 messageId = router.ccipSend(
            s_destinationChainId,
            acknowledgment
        );
        emit AcknowledgmentSent(_messageIdToAcknowledge, messageId);
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        bytes32 messageIdToAcknowledge = any2EvmMessage.messageId;
        address user;
        uint256 amount;
        string memory txType;
        (user, amount, txType) = abi.decode(
            any2EvmMessage.data,
            (address, uint, string)
        );
        Transaction storage txn = s_pendingTransactions[messageIdToAcknowledge];
        if (_compareStrings(txType, DEPOSIT)) {
            txn.txType = DEPOSIT;
        } else {
            txn.txType = WITHDRAW;
        }
        txn.amount = amount;
        txn.state = TransactionState.RECEIVED;
        txn.user = user;
        s_pendingTransactionIds.push(messageIdToAcknowledge);
        emit TransactionReceived(messageIdToAcknowledge, user, amount, txType);
    }

    function withdrawToken(
        address _beneficiary,
        address _token
    ) external onlyOwner {
        uint256 amount = IERC20(_token).balanceOf(address(this));

        if (amount == 0) revert NothingToWithdraw();

        IERC20(_token).safeTransfer(_beneficiary, amount);
    }

    function _depositCollateral(
        address _user,
        uint _amount
    ) private returns (bool success) {
        success = false;
        if (s_status == false) {
            revert CollateralTellerError_PausedWithDrawls();
        }
        if (int(_amount) < 0) {
            revert CollateralTellerError_AmountLessThanZero();
        }
        s_headStation.depositCollateral(s_collateralType, _amount, _user);
        success = true;
        emit CollateralTokenDeposited(_user, _amount);
    }

    function _withdrawCollateral(
        address _user,
        uint _amount
    ) private returns (bool success) {
        success = false;
        if (_amount > type(uint256).max) {
            revert CollateralTellerError_AmountOverFlown();
        }
        s_headStation.withdrawCollateral(s_collateralType, _amount, _user);
        success = true;
        emit CollateralTokenWithdrawn(_user, _amount);
    }

    function _compareStrings(
        string memory a,
        string memory b
    ) internal pure returns (bool eql) {
        eql = (keccak256(abi.encodePacked(a)) ==
            keccak256(abi.encodePacked(b)));
    }
}
