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
    address public investor3;
    uint256 public constant LOCK_PERIOD = 30 days;

    function setUp() public {
        admin = address(this);
        investor1 = address(0x1);
        investor2 = address(0x2);
        investor3 = address(0x3);

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
        vm.deal(investor3, 100 ether);
    }

    function testCompleteInvestmentFlow() public {
        // 1. Initial investment
        uint256 investmentAmount = 1000;
        investmentManager.invest(investor1, investmentAmount);

        address smartAccount = accountFactory.getAccount(investor1);
        assertEq(
            rwaToken.balanceOf(smartAccount),
            investmentAmount,
            "Incorrect initial investment balance"
        );

        // 2. Try to withdraw before lock period (should fail)
        vm.expectRevert("Lock period not over");
        investmentManager.initiateWithdrawal(investor1, investmentAmount);

        // 3. Fast forward time to just before lock period ends
        vm.warp(block.timestamp + LOCK_PERIOD - 1);
        vm.expectRevert("Lock period not over");
        investmentManager.initiateWithdrawal(investor1, investmentAmount);

        // 4. Fast forward time to after lock period
        vm.warp(block.timestamp + 2);

        // 5. Full withdrawal
        investmentManager.initiateWithdrawal(investor1, investmentAmount);
        assertEq(
            rwaToken.balanceOf(smartAccount),
            0,
            "Tokens not fully withdrawn"
        );

        // 6. Try to withdraw again (should fail)
        vm.expectRevert("No investment found");
        investmentManager.initiateWithdrawal(investor1, investmentAmount);
    }

    function testMultipleInvestorsAndPartialWithdrawals() public {
        // 1. Multiple investors invest
        investmentManager.invest(investor1, 1000);
        investmentManager.invest(investor2, 2000);
        investmentManager.invest(investor3, 3000);

        // 2. Fast forward time
        vm.warp(block.timestamp + LOCK_PERIOD + 1);

        // 3. Partial withdrawals
        investmentManager.initiateWithdrawal(investor1, 500);
        investmentManager.initiateWithdrawal(investor2, 1000);
        investmentManager.initiateWithdrawal(investor3, 1500);

        // 4. Check remaining balances
        assertEq(
            rwaToken.balanceOf(accountFactory.getAccount(investor1)),
            500,
            "Incorrect balance after partial withdrawal"
        );
        assertEq(
            rwaToken.balanceOf(accountFactory.getAccount(investor2)),
            1000,
            "Incorrect balance after partial withdrawal"
        );
        assertEq(
            rwaToken.balanceOf(accountFactory.getAccount(investor3)),
            1500,
            "Incorrect balance after partial withdrawal"
        );
    }

    function testInvestmentLimits() public {
        // 1. Try to invest 0 (should fail)
        vm.expectRevert("Investment amount must be greater than 0");
        investmentManager.invest(investor1, 0);

        // 2. Invest maximum uint256 value (edge case)
        uint256 maxInvestment = type(uint256).max;
        investmentManager.invest(investor1, maxInvestment);
        address smartAccount = accountFactory.getAccount(investor1);
        assertEq(
            rwaToken.balanceOf(smartAccount),
            maxInvestment,
            "Incorrect balance for max investment"
        );
    }

    function testPauseAndUnpause() public {
        // 1. Pause the contract
        investmentManager.pause();

        // 2. Try to invest while paused (should fail)
        vm.expectRevert();
        investmentManager.invest(investor1, 1000);

        // 3. Try to withdraw while paused (should fail)
        vm.expectRevert();
        investmentManager.initiateWithdrawal(investor1, 500);

        // 4. Unpause the contract
        investmentManager.unpause();

        // 5. Invest after unpausing (should succeed)
        investmentManager.invest(investor1, 1000);
        address smartAccount = accountFactory.getAccount(investor1);
        assertEq(
            rwaToken.balanceOf(smartAccount),
            1000,
            "Investment failed after unpausing"
        );
    }

    function testChangeLockPeriod() public {
        // 1. Change lock period
        uint256 newLockPeriod = 60 days;
        investmentManager.setLockPeriod(newLockPeriod);
        assertEq(
            investmentManager.lockPeriod(),
            newLockPeriod,
            "Lock period not updated"
        );

        // 2. Invest and try to withdraw before new lock period
        investmentManager.invest(investor1, 1000);
        vm.warp(block.timestamp + 45 days);
        vm.expectRevert("Lock period not over");
        investmentManager.initiateWithdrawal(investor1, 1000);

        // 3. Withdraw after new lock period
        vm.warp(block.timestamp + 16 days);
        investmentManager.initiateWithdrawal(investor1, 1000);
        address smartAccount = accountFactory.getAccount(investor1);
        assertEq(
            rwaToken.balanceOf(smartAccount),
            0,
            "Withdrawal failed after new lock period"
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

    function testMultipleInvestmentsAndWithdrawals() public {
        // 1. Multiple investments for the same investor
        investmentManager.invest(investor1, 1000);
        investmentManager.invest(investor1, 500);
        investmentManager.invest(investor1, 750);

        address smartAccount = accountFactory.getAccount(investor1);
        assertEq(
            rwaToken.balanceOf(smartAccount),
            2250,
            "Incorrect total investment balance"
        );

        // 2. Fast forward time
        vm.warp(block.timestamp + LOCK_PERIOD + 1);

        // 3. Multiple partial withdrawals
        investmentManager.initiateWithdrawal(investor1, 500);
        assertEq(
            rwaToken.balanceOf(smartAccount),
            1750,
            "Incorrect balance after first withdrawal"
        );

        investmentManager.initiateWithdrawal(investor1, 750);
        assertEq(
            rwaToken.balanceOf(smartAccount),
            1000,
            "Incorrect balance after second withdrawal"
        );

        // 4. Final full withdrawal
        investmentManager.initiateWithdrawal(investor1, 1000);
        assertEq(
            rwaToken.balanceOf(smartAccount),
            0,
            "Incorrect balance after final withdrawal"
        );
    }

    function testInvestmentTimestamps() public {
        // 1. Initial investment
        uint256 initialTimestamp = block.timestamp;
        investmentManager.invest(investor1, 1000);

        // 2. Check investment timestamp
        assertEq(
            investmentManager.investmentTimestamps(investor1),
            initialTimestamp,
            "Incorrect investment timestamp"
        );

        // 3. Additional investment
        vm.warp(block.timestamp + 10 days);
        uint256 newTimestamp = block.timestamp;
        investmentManager.invest(investor1, 500);

        // 4. Check that timestamp is updated
        assertEq(
            investmentManager.investmentTimestamps(investor1),
            newTimestamp,
            "Investment timestamp not updated"
        );
    }

    function testFailExcessiveWithdrawal() public {
        // 1. Initial investment
        investmentManager.invest(investor1, 1000);

        // 2. Fast forward time
        vm.warp(block.timestamp + LOCK_PERIOD + 1);

        // 3. Try to withdraw more than invested (should fail)
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        investmentManager.initiateWithdrawal(investor1, 1001);
    }

    function testRWATokenMinting() public {
        // 1. Check initial supply
        assertEq(rwaToken.totalSupply(), 0, "Initial supply should be 0");

        // 2. Invest and check minted amount
        uint256 investmentAmount = 1000;
        investmentManager.invest(investor1, investmentAmount);

        assertEq(
            rwaToken.totalSupply(),
            investmentAmount,
            "Incorrect total supply after investment"
        );

        // 3. Multiple investments and check total supply
        investmentManager.invest(investor2, 2000);
        investmentManager.invest(investor3, 3000);

        assertEq(
            rwaToken.totalSupply(),
            6000,
            "Incorrect total supply after multiple investments"
        );
    }

    function testSmartAccountCreation() public {
        // 1. Check that no account exists initially
        address initialAccount = accountFactory.getAccount(investor1);
        assertEq(
            initialAccount,
            address(0),
            "Account should not exist initially"
        );

        // 2. Invest and check account creation
        investmentManager.invest(investor1, 1000);
        address createdAccount = accountFactory.getAccount(investor1);
        assertTrue(
            createdAccount != address(0),
            "Account not created after investment"
        );

        // 3. Invest again and check that the same account is used
        investmentManager.invest(investor1, 500);
        address sameAccount = accountFactory.getAccount(investor1);
        assertEq(
            createdAccount,
            sameAccount,
            "New account created for existing investor"
        );
    }
}
