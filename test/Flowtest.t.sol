// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/InvestmentManager.sol";
import "../src/SmartAccountFactory.sol";
import "../src/SmartAccount.sol";
import "../src/RWAToken.sol";

contract InvestmentFlowTest is Test {
    InvestmentManager public investmentManager;
    SmartAccountFactory public accountFactory;
    RWAToken public rwaToken;
    SmartAccount public smartaccount;
    address public admin;
    address public investor1;
    address public investor2;
    uint256 public constant LOCK_PERIOD = 30 days;

    function setUp() public {
        admin = address(this);
        investor1 = address(0x1);
        investor2 = address(0x2);

        // Deploy contracts
        rwaToken = new RWAToken();
        accountFactory = new SmartAccountFactory(address(rwaToken));
        investmentManager = new InvestmentManager(
            address(rwaToken),
            address(accountFactory),
            LOCK_PERIOD
        );
        smartaccount = new SmartAccount(
            admin,
            address(rwaToken),
            address(investmentManager)
        );

        // Set up permissions
        rwaToken.setMinter(address(investmentManager));
        accountFactory.setInvestmentManager(address(investmentManager));

        // Fund investors with ETH for gas
        vm.deal(investor1, 100 ether);
        vm.deal(investor2, 100 ether);
    }

    function testInvestmentFlow() public {
        // Simulate bank payment confirmation and investment
        uint256 investmentAmount1 = 1000; // $1000
        uint256 investmentAmount2 = 2000; // $2000

        // Invest for investor1
        investmentManager.invest(investor1, investmentAmount1);

        // Check SmartAccount creation and token balance
        address smartAccount1 = accountFactory.getAccount(investor1);
        assertNotEq(smartAccount1, address(0), "SmartAccount not created");
        assertEq(
            rwaToken.balanceOf(smartAccount1),
            investmentAmount1,
            "Incorrect token balance"
        );

        // Invest for investor2
        investmentManager.invest(investor2, investmentAmount2);

        // Check SmartAccount creation and token balance
        address smartAccount2 = accountFactory.getAccount(investor2);
        assertNotEq(smartAccount2, address(0), "SmartAccount not created");
        assertEq(
            rwaToken.balanceOf(smartAccount2),
            investmentAmount2,
            "Incorrect token balance"
        );

        // Try to withdraw before lock period (should fail)
        vm.expectRevert("Lock period not over");
        investmentManager.initiateWithdrawal(investor1, investmentAmount1);

        // Fast forward time to after lock period
        vm.warp(block.timestamp + LOCK_PERIOD + 1 days);

        // Initiate withdrawal for investor1
        investmentManager.initiateWithdrawal(investor1, investmentAmount1);

        // Check token balance after withdrawal
        assertEq(
            rwaToken.balanceOf(smartAccount1),
            0,
            "Tokens not burned after withdrawal"
        );

        // Simulate profit calculation (50% profit)
        uint256 profitPercentage = 50;
        uint256 totalReturn = investmentAmount1 +
            ((investmentAmount1 * profitPercentage) / 100);

        // Log the return amount (in a real scenario, this would trigger a manual payout)
        emit log_named_uint("Return amount for investor1", totalReturn);

        // Test pausing functionality
        investmentManager.pause();

        vm.expectRevert("Pausable: paused");
        investmentManager.invest(investor2, 1000);

        investmentManager.unpause();

        // Test changing lock period
        uint256 newLockPeriod = 60 days;
        investmentManager.setLockPeriod(newLockPeriod);
        assertEq(
            investmentManager.lockPeriod(),
            newLockPeriod,
            "Lock period not updated"
        );
    }

    function testFailInvestmentAsNonOwner() public {
        vm.prank(investor1);
        investmentManager.invest(investor1, 1000);
    }

    function testFailWithdrawalAsNonOwner() public {
        vm.prank(investor1);
        investmentManager.initiateWithdrawal(investor1, 1000);
    }

    function testMultipleInvestments() public {
        uint256 initialInvestment = 1000;
        uint256 additionalInvestment = 500;

        // Initial investment
        investmentManager.invest(investor1, initialInvestment);

        // Additional investment
        investmentManager.invest(investor1, additionalInvestment);

        address smartAccount = accountFactory.getAccount(investor1);
        assertEq(
            rwaToken.balanceOf(smartAccount),
            initialInvestment + additionalInvestment,
            "Incorrect total investment"
        );
    }

    function testPartialWithdrawal() public {
        uint256 investmentAmount = 1000;
        uint256 partialWithdrawalAmount = 400;

        // Invest
        investmentManager.invest(investor1, investmentAmount);

        // Fast forward time
        vm.warp(block.timestamp + LOCK_PERIOD + 1 days);

        // Partial withdrawal
        investmentManager.initiateWithdrawal(
            investor1,
            partialWithdrawalAmount
        );

        address smartAccount = accountFactory.getAccount(investor1);
        assertEq(
            rwaToken.balanceOf(smartAccount),
            investmentAmount - partialWithdrawalAmount,
            "Incorrect remaining balance after partial withdrawal"
        );
    }

    // Additional helper functions can be added here for more complex scenarios
}
