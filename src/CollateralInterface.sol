// SPDX-License-Identifier: MIT

/**
 * @title CollateralInterface
 * @author Karthikeya Gundumogula
 * @notice This contract used to deposit and withdraw collateral on the other chains
 */
pragma solidity 0.8.19;

import {IRouterClient} from "@chainlink/contracts-ccip@1.4.0/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip@1.4.0/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip@1.4.0/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip@1.4.0/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts-ccip@1.4.0/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts-ccip@1.4.0/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";

using SafeERC20 for IERC20;

contract CollateralInterface is CCIPReceiver, OwnerIsCreator {
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);
    error CollateralTokenError_InsufficientCollateralBalance();
    error CollateralInterfaceError_SenderNotAllowedThisContractToTransferFunds();
    error CollateralInterfaceError_InsufficientCollateralBalance();
    error NothingToWithdraw();
    error DestinationChainNotAllowlisted(uint64 destinationChainSelector);
    error SourceChainNotAllowlisted(uint64 sourceChainSelector);
    error SenderNotAllowlisted(address sender);
    error InvalidReceiverAddress();
    error MessageWasNotSentByMessageTracker(bytes32 msgId);
    error MessageHasAlreadyBeenProcessedOnDestination(bytes32 msgId);

    enum MessageStatus {
        NotSent,
        Sent,
        ProcessedOnDestination
    }

    struct Transaction {
        string txType;
        address user;
        uint256 amount;
        MessageStatus status;
        bytes32 acknowledgerMessageId;
    }

    string private constant WITHDRAW = "W";
    string private constant DEPOSIT = "D";
    string private constant DEPOSITSUCCESS = "DS";
    string private constant DEPOSITFAIL = "DF";
    string private constant WITHDRAWSUCCESS = "WS";
    string private constant WITHDRAWFAIL = "WF";
    address public s_receivingContractAddress;
    uint64 public s_receivingChainId;
    mapping(bytes32 => Transaction) public s_transactionsInfo;
    mapping(address user => uint256 amount) public s_userBalances;
    mapping(address user => uint256 amount) public s_failedDeposits;
    mapping(address user => uint256 amount) public s_acceptedWithdrawls;

    event MessageSent(
        bytes32 indexed messageId,
        uint256 amount,
        address sender,
        string operation
    );
    event MessageProcessedOnDestination(
        bytes32 indexed messageId,
        string status
    );
    event DepositSuccess(
        bytes32 indexed messageId,
        address user,
        uint256 amount
    );
    event DepositFailed(
        bytes32 indexed messageId,
        address user,
        uint256 amount
    );
    event WithdrawRequestSuccess(
        bytes32 indexed messageId,
        address user,
        uint256 amount
    );
    event WithdrawRequestFailed(
        bytes32 indexed messageId,
        address user,
        uint256 amount
    );
    event CollateralWithdrawn(address user, uint256 amount);
    event FailedDepositWithdraw(address user, uint256 amount);

    IERC20 private s_linkToken;
    IERC20 private s_collateralToken;

    constructor(
        address _router,
        address _link,
        address _collateralToken
    ) CCIPReceiver(_router) {
        s_linkToken = IERC20(_link);
        s_collateralToken = IERC20(_collateralToken);
    }

    function initReceiver(
        address _recevierContract,
        uint64 _receiverChainId
    ) external onlyOwner {
        s_receivingContractAddress = _recevierContract;
        s_receivingChainId = _receiverChainId;
    }

    /**
     * @dev contract needs to be approved from the msg.sender to transfer collateral into this contract
     */

    function depositCollateral(uint256 _amount) external {
        if (s_collateralToken.balanceOf(msg.sender) < _amount) {
            revert CollateralTokenError_InsufficientCollateralBalance();
        }
        if (s_collateralToken.allowance(msg.sender, address(this)) < _amount) {
            revert CollateralInterfaceError_SenderNotAllowedThisContractToTransferFunds();
        }
        s_collateralToken.transferFrom(msg.sender, address(this), _amount);
        sendMessage(msg.sender, _amount, DEPOSIT);
    }

    function requestWithdrawl(uint256 _amount) external {
        if (s_userBalances[msg.sender] < _amount) {
            revert CollateralInterfaceError_InsufficientCollateralBalance();
        }
        sendMessage(msg.sender, _amount, WITHDRAW);
    }

    function sendMessage(
        address _user,
        uint256 _amount,
        string memory _txType
    ) private onlyOwner returns (bytes32 messageId) {
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(s_receivingContractAddress),
            data: abi.encode(_user, _amount, _txType),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 300_000})
            ),
            feeToken: address(s_linkToken)
        });

        IRouterClient router = IRouterClient(this.getRouter());

        uint256 fees = router.getFee(s_receivingChainId, evm2AnyMessage);

        if (fees > s_linkToken.balanceOf(address(this)))
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);

        s_linkToken.approve(address(router), fees);

        messageId = router.ccipSend(s_receivingChainId, evm2AnyMessage);

        s_transactionsInfo[messageId] = Transaction(
            _txType,
            _user,
            _amount,
            MessageStatus.Sent,
            bytes32(0)
        );

        emit MessageSent(messageId, _amount, msg.sender, _txType);
        return messageId;
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        (bytes32 initialMsgId, string memory status) = abi.decode(
            any2EvmMessage.data,
            (bytes32, string)
        );
        bytes32 acknowledgerMsgId = any2EvmMessage.messageId;
        s_transactionsInfo[initialMsgId]
            .acknowledgerMessageId = acknowledgerMsgId;
        Transaction memory txn = s_transactionsInfo[initialMsgId];
        if (compareStrings(status, DEPOSITSUCCESS)) {
            s_userBalances[txn.user] += txn.amount;
            emit DepositSuccess(initialMsgId, txn.user, txn.amount);
        } else if (compareStrings(status, DEPOSITFAIL)) {
            s_failedDeposits[txn.user] += txn.amount;
            emit DepositFailed(initialMsgId, txn.user, txn.amount);
        } else if (compareStrings(status, WITHDRAWSUCCESS)) {
            s_acceptedWithdrawls[txn.user] += txn.amount;
            emit WithdrawRequestSuccess(initialMsgId, txn.user, txn.amount);
        } else if (compareStrings(status, WITHDRAWFAIL)) {
            emit WithdrawRequestFailed(initialMsgId, txn.user, txn.amount);
        }

        if (s_transactionsInfo[initialMsgId].status == MessageStatus.Sent) {
            s_transactionsInfo[initialMsgId].status = MessageStatus
                .ProcessedOnDestination;
            emit MessageProcessedOnDestination(acknowledgerMsgId, status);
        } else if (
            s_transactionsInfo[initialMsgId].status ==
            MessageStatus.ProcessedOnDestination
        ) {
            revert MessageHasAlreadyBeenProcessedOnDestination(initialMsgId);
        } else {
            revert MessageWasNotSentByMessageTracker(initialMsgId);
        }
    }

    function withdrawToken(
        address _beneficiary,
        address _token
    ) public onlyOwner {
        uint256 amount = IERC20(_token).balanceOf(address(this));

        if (amount == 0) revert NothingToWithdraw();

        IERC20(_token).safeTransfer(_beneficiary, amount);
    }

    function withdrawCollateral(uint256 _amount) external {
        if (s_acceptedWithdrawls[msg.sender] < _amount) {
            revert CollateralInterfaceError_InsufficientCollateralBalance();
        }
        s_collateralToken.transfer(msg.sender, _amount);
        emit CollateralWithdrawn(msg.sender, _amount);
    }

    function withdrawFailedDeposits() external {
        uint256 amount = s_failedDeposits[msg.sender];
        if (amount < 0) {
            revert CollateralInterfaceError_InsufficientCollateralBalance();
        }
        s_collateralToken.transfer(msg.sender, amount);
        emit FailedDepositWithdraw(msg.sender, amount);
    }

    function compareStrings(
        string memory a,
        string memory b
    ) internal pure returns (bool eql) {
        eql = (keccak256(abi.encodePacked(a)) ==
            keccak256(abi.encodePacked(b)));
    }
}
