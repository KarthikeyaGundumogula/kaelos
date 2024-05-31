//SPDX-License-Identifier: MIT

/**
 * @title CollateralTeller
 * @author Karthikeya Gundumogula
 * @notice This contract is the receiver end of the CCIP interface that deposits collateral
 * @dev This contract updates the Users collateral balnce in the HeadStation contract
 * after receiving the msg from the sender contract
 */
pragma solidity ^0.8.20;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {EnumerableMap} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/utils/structs/EnumerableMap.sol";

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

contract CollateralTeller is CCIPReceiver, OwnerIsCreator {
    using EnumerableMap for EnumerableMap.Bytes32ToUintMap;

    error CollateralTellerError_UnAuthorizedOperation();
    error CollateralTellerError_InSufficientBalance();
    error CollateralTellerError_PausedWithDrawls();
    error CollateralTellerError_AmountLessThanZero();
    error CollateralTellerError_CollateralTransferFailed();
    error CollateralTellerError_AmountOverFlown();

    enum ErrorCode {
        RESOLVED,
        FAILED
    }

    struct FailedMessage {
        bytes32 messageId;
        ErrorCode errorCode;
    }

    IERC20 private s_linkToken;

    address public s_receiverContract;
    uint64 s_destinationChainSelector;
    uint256 private constant HEADSTATIONPRECISION = 10 ** 27;
    string private constant WITHDRAW = "W";
    string private constant DEPOSIT = "D";
    string private constant DEPOSITSUCCESS = "DS";
    string private constant DEPOSITFAIL = "DF";
    string private constant WITHDRAWSUCCESS = "WS";
    string private constant WITHDRAWFAIL = "WF";
    bytes32 private s_collateralType;
    HeadStation public s_headStation;
    uint256 private s_collateralDecimals;
    bool public s_status;
    EnumerableMap.Bytes32ToUintMap internal s_failedMessages;

    //--Events--//
    event AuthorizedAddressAdded(address user);
    event AuthorizedAddressRemoved(address user);
    event CollateralTokenDeposited(address user, uint amount);
    event CollateralTokenWithdrawn(address user, uint amount);
    event StausUpdated(bool status);
    event MessageFailed(bytes32 indexed messageId, bytes reason);

    constructor(
        address _headStation,
        bytes32 _collateralType,
        address _router
    ) CCIPReceiver(_router) {
        s_status = true;
        s_headStation = HeadStation(_headStation);
        s_collateralType = _collateralType;
        emit AuthorizedAddressAdded(msg.sender);
    }

    //--Authorization & Adminstration--//
    modifier authenticate() {
        if (msg.sender == address(this)) {
            revert CollateralTellerError_UnAuthorizedOperation();
        }
        _;
    }

    function changeStatus() external authenticate {
        s_status = !s_status;
        emit StausUpdated(s_status);
    }

    function initSenderContract(
        address _senderContract,
        uint64 _destinationChainId
    ) external onlyOwner {
        s_destinationChainSelector = _destinationChainId;
        s_receiverContract = _senderContract;
    }

    /**
     * @param any2EvmMessage  it is called by the ccip router
     */

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
    ) external authenticate {
        _ccipReceive(any2EvmMessage);
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        (string memory txType, address user, uint256 amount) = abi.decode(
            any2EvmMessage.data,
            (string, address, uint256)
        );
        if (
            keccak256(abi.encodePacked(txType)) ==
            keccak256(abi.encodePacked(DEPOSIT))
        ) {
            bool success = _depositCollateral(user, amount);
            if (success) {
                _sendCCIPMessage(DEPOSITSUCCESS, any2EvmMessage.messageId);
            } else {
                _sendCCIPMessage(DEPOSITFAIL, any2EvmMessage.messageId);
            }
        }
        if (
            keccak256(abi.encodePacked(txType)) ==
            keccak256(abi.encodePacked(WITHDRAW))
        ) {
            bool success = _withdrawCollateral(user, amount);
            if (success) {
                _sendCCIPMessage(WITHDRAWSUCCESS, any2EvmMessage.messageId);
            } else {
                _sendCCIPMessage(WITHDRAWFAIL, any2EvmMessage.messageId);
            }
        }
    }

    //--Deposit & Withdraw Collateral Token--//
    function _depositCollateral(
        address _user,
        uint _amount
    ) internal authenticate returns (bool success) {
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
    ) internal authenticate returns (bool success) {
        success = false;
        if (_amount > type(uint256).max) {
            revert CollateralTellerError_AmountOverFlown();
        }
        s_headStation.withdrawCollateral(s_collateralType, _amount, _user);
        success = true;
        emit CollateralTokenWithdrawn(_user, _amount);
    }

    function _sendCCIPMessage(
        string memory _status,
        bytes32 _acknowledgingMessageId
    ) internal returns (bytes32 messageId, uint256 fees) {
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(s_receiverContract),
            data: abi.encode(_status, _acknowledgingMessageId),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 400_000})
            ),
            feeToken: address(s_linkToken)
        });
        IRouterClient router = IRouterClient(this.getRouter());
        fees = router.getFee(s_destinationChainSelector, evm2AnyMessage);
        if (fees > s_linkToken.balanceOf(address(this)))
            revert CollateralTellerError_InSufficientBalance();
        s_linkToken.approve(address(router), fees);
        messageId = router.ccipSend(s_destinationChainSelector, evm2AnyMessage);
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
}
