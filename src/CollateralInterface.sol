// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IRouterClient} from "@chainlink/contracts-ccip@1.4.0/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip@1.4.0/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip@1.4.0/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip@1.4.0/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts-ccip@1.4.0/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts-ccip@1.4.0/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";

using SafeERC20 for IERC20;

contract MessageTracker is CCIPReceiver, OwnerIsCreator {
    
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); 
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

    struct MessageInfo {
        MessageStatus status;
        bytes32 acknowledgerMessageId;
    }

    mapping(uint64 => bool) public allowlistedDestinationChains;

    mapping(uint64 => bool) public allowlistedSourceChains;

    mapping(address => bool) public allowlistedSenders;

    mapping(bytes32 => MessageInfo) public messagesInfo;

    event MessageSent(
        bytes32 indexed messageId, 
        uint64 indexed destinationChainSelector,
        address receiver,
        string text, 
        address feeToken,
        uint256 fees 
    );
    event MessageProcessedOnDestination(
        bytes32 indexed messageId,     
        bytes32 indexed acknowledgedMsgId,
        uint64 indexed sourceChainSelector,
        address sender 
    );

    IERC20 private s_linkToken;

    constructor(address _router, address _link) CCIPReceiver(_router) {
        s_linkToken = IERC20(_link);
    }

    modifier onlyAllowlistedDestinationChain(uint64 _destinationChainSelector) {
        if (!allowlistedDestinationChains[_destinationChainSelector])
            revert DestinationChainNotAllowlisted(_destinationChainSelector);
        _;
    }
    modifier onlyAllowlisted(uint64 _sourceChainSelector, address _sender) {
        if (!allowlistedSourceChains[_sourceChainSelector])
            revert SourceChainNotAllowlisted(_sourceChainSelector);
        if (!allowlistedSenders[_sender]) revert SenderNotAllowlisted(_sender);
        _;
    }
    modifier validateReceiver(address _receiver) {
        if (_receiver == address(0)) revert InvalidReceiverAddress();
        _;
    }
    function allowlistDestinationChain(
        uint64 _destinationChainSelector,
        bool allowed
    ) external onlyOwner {
        allowlistedDestinationChains[_destinationChainSelector] = allowed;
    }
    function allowlistSourceChain(
        uint64 _sourceChainSelector,
        bool allowed
    ) external onlyOwner {
        allowlistedSourceChains[_sourceChainSelector] = allowed;
    }
    function allowlistSender(address _sender, bool allowed) external onlyOwner {
        allowlistedSenders[_sender] = allowed;
    }
    function sendMessagePayLINK(
        uint64 _destinationChainSelector,
        address _receiver,
        string calldata _text
    )
        external
        onlyOwner
        onlyAllowlistedDestinationChain(_destinationChainSelector)
        validateReceiver(_receiver)
        returns (bytes32 messageId)
    {
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _receiver,
            _text,
            address(s_linkToken)
        );

        IRouterClient router = IRouterClient(this.getRouter());

        uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

        if (fees > s_linkToken.balanceOf(address(this)))
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);

        s_linkToken.approve(address(router), fees);

        messageId = router.ccipSend(_destinationChainSelector, evm2AnyMessage);

        messagesInfo[messageId].status = MessageStatus.Sent;

        emit MessageSent(
            messageId,
            _destinationChainSelector,
            _receiver,
            _text,
            address(s_linkToken),
            fees
        );
        return messageId;
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        override
        onlyAllowlisted(
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address))
        )
    {
        bytes32 initialMsgId = abi.decode(any2EvmMessage.data, (bytes32)); // Decode the data sent by the receiver
        bytes32 acknowledgerMsgId = any2EvmMessage.messageId;
        messagesInfo[initialMsgId].acknowledgerMessageId = acknowledgerMsgId; // Store the messageId of the received message

        if (messagesInfo[initialMsgId].status == MessageStatus.Sent) {
            messagesInfo[initialMsgId].status = MessageStatus
                .ProcessedOnDestination;
            emit MessageProcessedOnDestination(
                acknowledgerMsgId,
                initialMsgId,
                any2EvmMessage.sourceChainSelector,
                abi.decode(any2EvmMessage.sender, (address))
            );
        } else if (
            messagesInfo[initialMsgId].status ==
            MessageStatus.ProcessedOnDestination
        ) {
            revert MessageHasAlreadyBeenProcessedOnDestination(initialMsgId);
        } else {
            revert MessageWasNotSentByMessageTracker(initialMsgId);
        }
    }

    function _buildCCIPMessage(
        address _receiver,
        string calldata _text,
        address _feeTokenAddress
    ) private pure returns (Client.EVM2AnyMessage memory) {
        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(_receiver), // ABI-encoded receiver address
                data: abi.encode(_text), // ABI-encoded string
                tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array as no tokens are transferred
                extraArgs: Client._argsToBytes(
                    Client.EVMExtraArgsV1({gasLimit: 300_000})
                ),
                feeToken: _feeTokenAddress
            });
    }
    function withdrawToken(
        address _beneficiary,
        address _token
    ) public onlyOwner {
        uint256 amount = IERC20(_token).balanceOf(address(this));

        if (amount == 0) revert NothingToWithdraw();

        IERC20(_token).safeTransfer(_beneficiary, amount);
    }
}