// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Escrow is ReentrancyGuard {
    error Escrow__NotTheBuyer();
    error Escrow__NotTheSeller();
    error Escrow__NotTheArbitrator();
    error Escrow__InvalidState();
    error Escrow__InvalidEthAmount();
    error Escrow__EthNotAccepted();
    error Escrow_EthTransferFailed();
    error Escrow__TokenTransferFailed();

    address public immutable arbitrator;
    uint256 public agreementCount;

    enum State {
        AWAITING_PAYMENT,
        AWAITING_DELIVERY,
        COMPLETE,
        DISPUTE
    }

    struct Agreement {
        address buyer;
        address seller;
        address tokenAddress;
        uint256 amount;
        State state;
    }

    mapping(uint256 agreementId => Agreement agreement) public agreements;

    event AgreementCreated(
        uint256 indexed agreementId, address indexed buyer, address indexed seller, uint256 amount, address tokenAddress
    );
    event PaymentDeposited(uint256 indexed agreementId);
    event ItemReceived(uint256 indexed agreementId);
    event DisputeResolved(uint256 indexed agreementId, bool buyerWins);

    modifier onlyBuyer(uint256 agreementId) {
        if (msg.sender != agreements[agreementId].buyer) {
            revert Escrow__NotTheBuyer();
        }
        _;
    }

    modifier onlySeller(uint256 agreementId) {
        if (msg.sender != agreements[agreementId].seller) {
            revert Escrow__NotTheSeller();
        }
        _;
    }

    modifier onlyArbitrator() {
        if (msg.sender != arbitrator) {
            revert Escrow__NotTheArbitrator();
        }
        _;
    }

    modifier inState(uint256 agreementId, State state) {
        if (agreements[agreementId].state != state) {
            revert Escrow__InvalidState();
        }
        _;
    }

    constructor(address _arbitrator) {
        arbitrator = _arbitrator;
    }

    function createAgreement(address _seller, address _tokenAddress, uint256 _amount) external returns (uint256) {
        agreementCount++;
        uint256 agreementId = agreementCount;
        agreements[agreementId] = Agreement({
            buyer: msg.sender,
            seller: _seller,
            tokenAddress: _tokenAddress,
            amount: _amount,
            state: State.AWAITING_PAYMENT
        });
        emit AgreementCreated(agreementId, msg.sender, _seller, _amount, _tokenAddress);
        return agreementId;
    }

    function depositPayment(uint256 agreementId)
        external
        payable
        onlyBuyer(agreementId)
        inState(agreementId, State.AWAITING_PAYMENT)
        nonReentrant
    {
        Agreement storage agreement = agreements[agreementId];
        agreement.state = State.AWAITING_DELIVERY;
        if (agreement.tokenAddress == address(0)) {
            if (msg.value < agreement.amount) {
                revert Escrow__InvalidEthAmount();
            }
        } else {
            if (msg.value > 0) {
                revert Escrow__EthNotAccepted();
            }
            IERC20 token = IERC20(agreement.tokenAddress);
            bool success = token.transferFrom(msg.sender, address(this), agreement.amount);
            if (!success) {
                revert Escrow__TokenTransferFailed();
            }
        }
        emit PaymentDeposited(agreementId);
    }

    function confirmDelivery(uint256 agreementId)
        external
        onlyBuyer(agreementId)
        inState(agreementId, State.AWAITING_DELIVERY)
        nonReentrant
    {
        Agreement storage agreement = agreements[agreementId];
        agreement.state = State.COMPLETE;

        if (agreement.tokenAddress == address(0)) {
            (bool success,) = payable(agreement.seller).call{value: agreement.amount}("");
            if (!success) {
                revert Escrow_EthTransferFailed();
            }
        } else {
            IERC20 token = IERC20(agreement.tokenAddress);
            bool success = token.transfer(agreement.seller, agreement.amount);
            if (!success) {
                revert Escrow__TokenTransferFailed();
            }
        }
        emit ItemReceived(agreementId);
    }

    function raiseDispute(uint256 agreementId)
        external
        onlyBuyer(agreementId)
        inState(agreementId, State.AWAITING_DELIVERY)
        nonReentrant
    {
        agreements[agreementId].state = State.DISPUTE;
    }

    function resolveDispute(uint256 agreementId, bool buyerWins)
        external
        onlyArbitrator
        inState(agreementId, State.DISPUTE)
        nonReentrant
    {
        Agreement storage agreement = agreements[agreementId];
        agreement.state = State.COMPLETE;

        if (buyerWins) {
            if (agreement.tokenAddress == address(0)) {
                (bool success,) = payable(agreement.buyer).call{value: agreement.amount}("");
                if (!success) {
                    revert Escrow_EthTransferFailed();
                }
            } else {
                IERC20 token = IERC20(agreement.tokenAddress);
                bool success = token.transfer(agreement.buyer, agreement.amount);
                if (!success) {
                    revert Escrow__TokenTransferFailed();
                }
            }
        } else {
            if (agreement.tokenAddress == address(0)) {
                (bool success,) = payable(agreement.seller).call{value: agreement.amount}("");
                if (!success) {
                    revert Escrow_EthTransferFailed();
                }
            } else {
                IERC20 token = IERC20(agreement.tokenAddress);
                bool success = token.transfer(agreement.seller, agreement.amount);
                if (!success) {
                    revert Escrow__TokenTransferFailed();
                }
            }
        }
        emit DisputeResolved(agreementId, buyerWins);
    }
}
