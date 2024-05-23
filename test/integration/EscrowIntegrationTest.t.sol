// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import {DeployEscrow} from "../../script/DeployEscrow.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Escrow} from "../../src/Escrow.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract EscrowIntegrationTest is Test {
    Escrow public escrow;
    ERC20Mock public erc20Mock;
    HelperConfig public helperConfig;

    address public arbitrator = address(1);
    address public buyer = address(2);
    address public seller = address(3);

    uint256 private constant VALID_DEPOSIT_AMOUNT = 100e18;
    uint256 private constant VALID_DEPOSIT_ETH_AMOUNT = 1 ether;

    function setUp() public {
        // Deploy the Escrow contract using the deployment script
        DeployEscrow deployer = new DeployEscrow();
        escrow = deployer.run(arbitrator);

        // Deploy the ERC20Mock token using the helper config script
        helperConfig = new HelperConfig();
        erc20Mock = helperConfig.deployERC20Mock();

        // Mint and approve tokens for the buyer
        vm.startPrank(buyer);
        erc20Mock.mint(buyer, VALID_DEPOSIT_AMOUNT);
        erc20Mock.approve(address(escrow), VALID_DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function testDeployEscrow() public {
        DeployEscrow deployer = new DeployEscrow();
        Escrow deployedEscrow = deployer.run(arbitrator);

        assertEq(deployedEscrow.arbitrator(), arbitrator);
    }

    function testDeployERC20Mock() public {
        ERC20Mock deployedERC20Mock = helperConfig.deployERC20Mock();

        // Test if ERC20Mock was deployed correctly
        assertEq(deployedERC20Mock.name(), "ERC20Mock");
        assertEq(deployedERC20Mock.symbol(), "E20M");
        assertEq(deployedERC20Mock.decimals(), 18);
    }

    function testCreateAgreementWithEth() public {
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(0), VALID_DEPOSIT_ETH_AMOUNT);
        vm.stopPrank();

        (address _buyer, address _seller, address tokenAddress, uint256 amount, Escrow.State state) =
            escrow.agreements(agreementId);

        assertEq(_buyer, buyer);
        assertEq(_seller, seller);
        assertEq(tokenAddress, address(0));
        assertEq(amount, VALID_DEPOSIT_ETH_AMOUNT);
        assertEq(uint256(state), uint256(Escrow.State.AWAITING_PAYMENT));
    }

    function testDepositPaymentWithEth() public {
        vm.deal(buyer, VALID_DEPOSIT_ETH_AMOUNT);

        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(0), VALID_DEPOSIT_ETH_AMOUNT);
        escrow.depositPayment{value: VALID_DEPOSIT_ETH_AMOUNT}(agreementId);
        vm.stopPrank();

        (,,,, Escrow.State state) = escrow.agreements(agreementId);

        assertEq(uint256(state), uint256(Escrow.State.AWAITING_DELIVERY));
    }

    function testConfirmDeliveryWithEth() public {
        vm.deal(buyer, VALID_DEPOSIT_ETH_AMOUNT);

        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(0), VALID_DEPOSIT_ETH_AMOUNT);
        escrow.depositPayment{value: VALID_DEPOSIT_ETH_AMOUNT}(agreementId);
        escrow.confirmDelivery(agreementId);
        vm.stopPrank();

        (,,,, Escrow.State state) = escrow.agreements(agreementId);
        assertEq(uint256(state), uint256(Escrow.State.COMPLETE));
        assertEq(seller.balance, VALID_DEPOSIT_ETH_AMOUNT);
    }

    function testRaiseDisputeWithEth() public {
        vm.deal(buyer, VALID_DEPOSIT_ETH_AMOUNT);

        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(0), VALID_DEPOSIT_ETH_AMOUNT);
        escrow.depositPayment{value: VALID_DEPOSIT_ETH_AMOUNT}(agreementId);
        escrow.raiseDispute(agreementId);
        vm.stopPrank();

        (,,,, Escrow.State state) = escrow.agreements(agreementId);
        assertEq(uint256(state), uint256(Escrow.State.DISPUTE));
    }

    function testResolveDisputeBuyerWinsWithEth() public {
        vm.deal(buyer, VALID_DEPOSIT_ETH_AMOUNT);

        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(0), VALID_DEPOSIT_ETH_AMOUNT);
        escrow.depositPayment{value: VALID_DEPOSIT_ETH_AMOUNT}(agreementId);
        escrow.raiseDispute(agreementId);
        vm.stopPrank();

        vm.startPrank(arbitrator);
        escrow.resolveDispute(agreementId, true);
        vm.stopPrank();

        (,,,, Escrow.State state) = escrow.agreements(agreementId);
        assertEq(uint256(state), uint256(Escrow.State.COMPLETE));
        assertEq(buyer.balance, VALID_DEPOSIT_ETH_AMOUNT);
    }

    function testResolveDisputeSellerWinsWithEth() public {
        vm.deal(buyer, VALID_DEPOSIT_ETH_AMOUNT);

        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(0), VALID_DEPOSIT_ETH_AMOUNT);
        escrow.depositPayment{value: VALID_DEPOSIT_ETH_AMOUNT}(agreementId);
        escrow.raiseDispute(agreementId);
        vm.stopPrank();

        vm.startPrank(arbitrator);
        escrow.resolveDispute(agreementId, false);
        vm.stopPrank();

        (,,,, Escrow.State state) = escrow.agreements(agreementId);
        assertEq(uint256(state), uint256(Escrow.State.COMPLETE));
        assertEq(seller.balance, VALID_DEPOSIT_ETH_AMOUNT);
    }

    function testCreateAgreementWithERC20() public {
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(erc20Mock), VALID_DEPOSIT_AMOUNT);
        vm.stopPrank();

        (address _buyer, address _seller, address tokenAddress, uint256 amount, Escrow.State state) =
            escrow.agreements(agreementId);

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

    function testRaiseDisputeWithERC20() public {
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(erc20Mock), VALID_DEPOSIT_AMOUNT);
        escrow.depositPayment(agreementId);
        escrow.raiseDispute(agreementId);
        vm.stopPrank();

        (,,,, Escrow.State state) = escrow.agreements(agreementId);
        assertEq(uint256(state), uint256(Escrow.State.DISPUTE));
    }

    function testResolveDisputeBuyerWinsWithERC20() public {
        vm.startPrank(buyer);
        uint256 agreementId = escrow.createAgreement(seller, address(erc20Mock), VALID_DEPOSIT_AMOUNT);
        escrow.depositPayment(agreementId);
        escrow.raiseDispute(agreementId);
        vm.stopPrank();

        vm.startPrank(arbitrator);
        escrow.resolveDispute(agreementId, true);
        vm.stopPrank();

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

        vm.startPrank(arbitrator);
        escrow.resolveDispute(agreementId, false);
        vm.stopPrank();

        (,,,, Escrow.State state) = escrow.agreements(agreementId);
        assertEq(uint256(state), uint256(Escrow.State.COMPLETE));
        assertEq(erc20Mock.balanceOf(seller), VALID_DEPOSIT_AMOUNT);
    }
}
