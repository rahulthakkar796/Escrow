// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Escrow} from "../../src/Escrow.sol";
import {DeployEscrow} from "../../script/DeployEscrow.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract EscrowTest is Test {
    Escrow public escrow;
    ERC20Mock public erc20Mock;
    HelperConfig public helperConfig;

    address public arbitrator = address(1);
    address public buyer = address(2);
    address public seller = address(3);

    uint256 private constant VALID_DEPOSIT_AMOUNT = 100e18;
    uint256 private constant VALID_DEPOSIT_ETH_AMOUNT = 1 ether;
    uint256 private constant INVALID_DEPOSIT_ETH_AMOUNT = 0.5 ether;

    function setUp() public {
        DeployEscrow deployer = new DeployEscrow();
        escrow = deployer.run(arbitrator);

        helperConfig = new HelperConfig();
        erc20Mock = helperConfig.deployERC20Mock();
        erc20Mock.mint(buyer, VALID_DEPOSIT_AMOUNT);

        // Approve escrow contract to spend buyer's tokens
        vm.startPrank(buyer);
        erc20Mock.approve(address(escrow), VALID_DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    /////////////////////////
    ///// ETH Tests//////////
    /////////////////////////

    function testCreateAgreement() public {
        vm.startPrank(buyer);
        uint256 agreementCountBefore = escrow.agreementCount();
        uint256 agreementId = escrow.createAgreement(seller, address(0), VALID_DEPOSIT_ETH_AMOUNT);
        vm.stopPrank();

        uint256 agreementCountAfter = escrow.agreementCount();
        (address _buyer, address _seller, address tokenAddress, uint256 amount, Escrow.State state) =
            escrow.agreements(agreementId);

        assertEq(agreementCountBefore + 1, agreementCountAfter);
        assertEq(agreementCountAfter, agreementId);
        assertEq(_buyer, buyer);
        assertEq(_seller, seller);
        assertEq(tokenAddress, address(0));
        assertEq(amount, VALID_DEPOSIT_ETH_AMOUNT);
        assertEq(uint256(state), uint256(Escrow.State.AWAITING_PAYMENT));
    }

    function testDepositPayment() public {
        vm.deal(buyer, VALID_DEPOSIT_ETH_AMOUNT);
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(0), VALID_DEPOSIT_ETH_AMOUNT);
        escrow.depositPayment{value: VALID_DEPOSIT_ETH_AMOUNT}(agreementId);
        vm.stopPrank();

        (,,,, Escrow.State state) = escrow.agreements(agreementId);

        assertEq(uint256(state), uint256(Escrow.State.AWAITING_DELIVERY));
    }

    function testRevertDepositPaymentInsufficientETH() public {
        vm.deal(buyer, INVALID_DEPOSIT_ETH_AMOUNT);
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(0), VALID_DEPOSIT_ETH_AMOUNT);
        vm.expectRevert(Escrow.Escrow__InvalidEthAmount.selector);
        escrow.depositPayment{value: INVALID_DEPOSIT_ETH_AMOUNT}(agreementId);
        vm.stopPrank();
    }

    function testRevertDepositPaymentNotBuyer() public {
        vm.deal(buyer, VALID_DEPOSIT_ETH_AMOUNT);
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(0), VALID_DEPOSIT_ETH_AMOUNT);
        vm.stopPrank();

        vm.deal(seller, VALID_DEPOSIT_ETH_AMOUNT);
        vm.startPrank(seller);
        vm.expectRevert(Escrow.Escrow__NotTheBuyer.selector);
        escrow.depositPayment{value: VALID_DEPOSIT_ETH_AMOUNT}(agreementId);
        vm.stopPrank();
    }

    function testConfirmDelivery() public {
        vm.deal(buyer, VALID_DEPOSIT_ETH_AMOUNT);
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(0), VALID_DEPOSIT_ETH_AMOUNT);
        escrow.depositPayment{value: VALID_DEPOSIT_ETH_AMOUNT}(agreementId);
        escrow.confirmDelivery(agreementId);
        vm.stopPrank();

        (,,,, Escrow.State state) = escrow.agreements(agreementId);

        console.log("state:", uint256(state));

        assertEq(uint256(state), uint256(Escrow.State.COMPLETE));
        assertEq(seller.balance, VALID_DEPOSIT_ETH_AMOUNT);
    }

    function testRevertConfirmDeliveryIfNotBuyer() public {
        vm.deal(buyer, VALID_DEPOSIT_ETH_AMOUNT);
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(0), VALID_DEPOSIT_ETH_AMOUNT);
        escrow.depositPayment{value: VALID_DEPOSIT_ETH_AMOUNT}(agreementId);
        vm.stopPrank();

        vm.deal(seller, VALID_DEPOSIT_ETH_AMOUNT);
        vm.startPrank(seller);
        vm.expectRevert(Escrow.Escrow__NotTheBuyer.selector);
        escrow.confirmDelivery(agreementId);
        vm.stopPrank();
    }

    function testRevertConfirmDelieveryIfInvalidEthAmountPassed() public {
        vm.deal(buyer, VALID_DEPOSIT_ETH_AMOUNT);
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(0), VALID_DEPOSIT_ETH_AMOUNT);
        escrow.depositPayment{value: VALID_DEPOSIT_ETH_AMOUNT}(agreementId);
        vm.deal(address(escrow), 0 ether);
        vm.expectRevert(Escrow.Escrow_EthTransferFailed.selector);
        escrow.confirmDelivery(agreementId);
        vm.stopPrank();
    }

    function testRaiseDispute() public {
        vm.deal(buyer, VALID_DEPOSIT_ETH_AMOUNT);
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(0), VALID_DEPOSIT_ETH_AMOUNT);
        escrow.depositPayment{value: VALID_DEPOSIT_ETH_AMOUNT}(agreementId);
        escrow.raiseDispute(agreementId);
        vm.stopPrank();

        (,,,, Escrow.State state) = escrow.agreements(agreementId);

        assertEq(uint256(state), uint256(Escrow.State.DISPUTE));
    }

    function testRevertRaiseDisputeNotBuyer() public {
        vm.deal(buyer, VALID_DEPOSIT_ETH_AMOUNT);
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(0), VALID_DEPOSIT_ETH_AMOUNT);
        escrow.depositPayment{value: VALID_DEPOSIT_ETH_AMOUNT}(agreementId);
        vm.stopPrank();

        vm.startPrank(seller);
        vm.expectRevert(Escrow.Escrow__NotTheBuyer.selector);
        escrow.raiseDispute(agreementId);
        vm.stopPrank();
    }

    function testResolveDisputeBuyerWins() public {
        vm.deal(buyer, VALID_DEPOSIT_ETH_AMOUNT);
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(0), VALID_DEPOSIT_ETH_AMOUNT);
        escrow.depositPayment{value: VALID_DEPOSIT_ETH_AMOUNT}(agreementId);
        escrow.raiseDispute(agreementId);
        vm.stopPrank();

        vm.prank(arbitrator);
        escrow.resolveDispute(agreementId, true);

        (,,,, Escrow.State state) = escrow.agreements(agreementId);

        assertEq(uint256(state), uint256(Escrow.State.COMPLETE));
        assertEq(buyer.balance, VALID_DEPOSIT_ETH_AMOUNT);
    }

    function testResolveDisputeSellerWins() public {
        vm.deal(buyer, VALID_DEPOSIT_ETH_AMOUNT);
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(0), VALID_DEPOSIT_ETH_AMOUNT);
        escrow.depositPayment{value: VALID_DEPOSIT_ETH_AMOUNT}(agreementId);
        escrow.raiseDispute(agreementId);
        vm.stopPrank();

        vm.prank(arbitrator);
        escrow.resolveDispute(agreementId, false);

        (,,,, Escrow.State state) = escrow.agreements(agreementId);

        assertEq(uint256(state), uint256(Escrow.State.COMPLETE));
        assertEq(seller.balance, VALID_DEPOSIT_ETH_AMOUNT);
    }

    function testRevertResolveDisputeNotArbitrator() public {
        vm.deal(buyer, VALID_DEPOSIT_ETH_AMOUNT);
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(0), VALID_DEPOSIT_ETH_AMOUNT);
        escrow.depositPayment{value: VALID_DEPOSIT_ETH_AMOUNT}(agreementId);
        escrow.raiseDispute(agreementId);
        vm.stopPrank();

        vm.prank(seller);
        vm.expectRevert(Escrow.Escrow__NotTheArbitrator.selector);
        escrow.resolveDispute(agreementId, true);
    }

    function testRevertResolveDisputeForBuyerIfEthTransferFailed() public {
        vm.deal(buyer, VALID_DEPOSIT_ETH_AMOUNT);
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(0), VALID_DEPOSIT_ETH_AMOUNT);
        escrow.depositPayment{value: VALID_DEPOSIT_ETH_AMOUNT}(agreementId);
        escrow.raiseDispute(agreementId);
        vm.stopPrank();

        vm.startPrank(arbitrator);
        vm.deal(address(escrow), 0 ether);
        vm.expectRevert(Escrow.Escrow_EthTransferFailed.selector);
        escrow.resolveDispute(agreementId, true);
        vm.stopPrank();
    }

    function testRevertResolveDisputeForSellerIfEthTransferFailed() public {
        vm.deal(buyer, VALID_DEPOSIT_ETH_AMOUNT);
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(0), VALID_DEPOSIT_ETH_AMOUNT);
        escrow.depositPayment{value: VALID_DEPOSIT_ETH_AMOUNT}(agreementId);
        escrow.raiseDispute(agreementId);
        vm.stopPrank();

        vm.startPrank(arbitrator);
        vm.deal(address(escrow), 0 ether);
        vm.expectRevert(Escrow.Escrow_EthTransferFailed.selector);
        escrow.resolveDispute(agreementId, false);
        vm.stopPrank();
    }

    /////////////////////////
    //////// ERC20 Tests ////
    ////////////////////////

    function testCreateAgreementWithERC20() public {
        vm.startPrank(buyer);
        uint256 agreementCountBefore = escrow.agreementCount();
        uint256 agreementId = escrow.createAgreement(seller, address(erc20Mock), VALID_DEPOSIT_AMOUNT);
        vm.stopPrank();

        uint256 agreementCountAfter = escrow.agreementCount();
        (address _buyer, address _seller, address tokenAddress, uint256 amount, Escrow.State state) =
            escrow.agreements(agreementId);

        assertEq(agreementCountBefore + 1, agreementCountAfter);
        assertEq(agreementCountAfter, agreementId);
        assertEq(_buyer, buyer);
        assertEq(_seller, seller);
        assertEq(tokenAddress, address(erc20Mock));
        assertEq(amount, VALID_DEPOSIT_AMOUNT);
        assertEq(uint256(state), uint256(Escrow.State.AWAITING_PAYMENT));
    }

    function testDepositPaymentWithERC20() public {
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(erc20Mock), VALID_DEPOSIT_AMOUNT);
        escrow.depositPayment(agreementId);
        vm.stopPrank();

        (,,,, Escrow.State state) = escrow.agreements(agreementId);

        assertEq(uint256(state), uint256(Escrow.State.AWAITING_DELIVERY));
    }

    function testRevertDepositIfSuppliedEth() public {
        vm.deal(buyer, VALID_DEPOSIT_ETH_AMOUNT);
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(erc20Mock), VALID_DEPOSIT_AMOUNT);
        vm.expectRevert(Escrow.Escrow__EthNotAccepted.selector);
        escrow.depositPayment{value: VALID_DEPOSIT_ETH_AMOUNT}(agreementId);
        vm.stopPrank();
    }

    function testConfirmDeliveryWithERC20() public {
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(erc20Mock), VALID_DEPOSIT_AMOUNT);
        escrow.depositPayment(agreementId);
        escrow.confirmDelivery(agreementId);
        vm.stopPrank();

        (,,,, Escrow.State state) = escrow.agreements(agreementId);

        assertEq(uint256(state), uint256(Escrow.State.COMPLETE));
        assertEq(erc20Mock.balanceOf(seller), VALID_DEPOSIT_AMOUNT);
    }

    function testRevertConfirmDeliveryIfNotBuyerWithERC20() public {
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(erc20Mock), VALID_DEPOSIT_AMOUNT);
        escrow.depositPayment(agreementId);
        vm.stopPrank();

        vm.startPrank(seller);
        vm.expectRevert(Escrow.Escrow__NotTheBuyer.selector);
        escrow.confirmDelivery(agreementId);
        vm.stopPrank();
    }

    function testRaiseDisputeWithERC20() public {
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(erc20Mock), VALID_DEPOSIT_AMOUNT);
        escrow.depositPayment(agreementId);
        escrow.raiseDispute(agreementId);
        vm.stopPrank();

        (,,,, Escrow.State state) = escrow.agreements(agreementId);

        assertEq(uint256(state), uint256(Escrow.State.DISPUTE));
    }

    function testRevertRaiseDisputeNotBuyerWithERC20() public {
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(erc20Mock), VALID_DEPOSIT_AMOUNT);
        escrow.depositPayment(agreementId);
        vm.stopPrank();

        vm.startPrank(seller);
        vm.expectRevert(Escrow.Escrow__NotTheBuyer.selector);
        escrow.raiseDispute(agreementId);
        vm.stopPrank();
    }

    function testResolveDisputeBuyerWinsWithERC20() public {
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(erc20Mock), VALID_DEPOSIT_AMOUNT);
        escrow.depositPayment(agreementId);
        escrow.raiseDispute(agreementId);
        vm.stopPrank();

        vm.prank(arbitrator);
        escrow.resolveDispute(agreementId, true);

        (,,,, Escrow.State state) = escrow.agreements(agreementId);

        assertEq(uint256(state), uint256(Escrow.State.COMPLETE));
        assertEq(erc20Mock.balanceOf(buyer), VALID_DEPOSIT_AMOUNT);
    }

    function testResolveDisputeSellerWinsWithERC20() public {
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(erc20Mock), VALID_DEPOSIT_AMOUNT);
        escrow.depositPayment(agreementId);
        escrow.raiseDispute(agreementId);
        vm.stopPrank();

        vm.prank(arbitrator);
        escrow.resolveDispute(agreementId, false);

        (,,,, Escrow.State state) = escrow.agreements(agreementId);

        assertEq(uint256(state), uint256(Escrow.State.COMPLETE));
        assertEq(erc20Mock.balanceOf(seller), VALID_DEPOSIT_AMOUNT);
    }

    function testRevertResolveDisputeNotArbitratorWithERC20() public {
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(erc20Mock), VALID_DEPOSIT_AMOUNT);
        escrow.depositPayment(agreementId);
        escrow.raiseDispute(agreementId);
        vm.stopPrank();

        vm.prank(seller);
        vm.expectRevert(Escrow.Escrow__NotTheArbitrator.selector);
        escrow.resolveDispute(agreementId, true);
    }
}
