// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./SmartAccountFactory.sol";
import "./SmartAccount.sol";
import "./RWAToken.sol";

contract InvestmentManager is Ownable, Pausable, ReentrancyGuard {
    RWAToken public rwaToken; // Change this to RWAToken instead of IERC20
    SmartAccountFactory public accountFactory;
    uint256 public lockPeriod;
    mapping(address => uint256) public investmentTimestamps;

    event InvestmentMade(
        address indexed investor,
        uint256 amount,
        uint256 tokens
    );
    event WithdrawalInitiated(
        address indexed investor,
        uint256 amount,
        uint256 tokens
    );
    event LockPeriodChanged(uint256 newLockPeriod);

    constructor(
        address _rwaToken,
        address _accountFactory,
        uint256 _lockPeriod
    ) Ownable(msg.sender) {
        require(
            _rwaToken != address(0) && _accountFactory != address(0),
            "Invalid addresses"
        );
        rwaToken = RWAToken(_rwaToken); // Cast to RWAToken
        accountFactory = SmartAccountFactory(_accountFactory);
        lockPeriod = _lockPeriod;
    }

    function invest(
        address investor,
        uint256 amount
    ) external onlyOwner whenNotPaused nonReentrant {
        require(amount > 0, "Investment amount must be greater than 0");

        address smartAccount = accountFactory.getAccount(investor);
        if (smartAccount == address(0)) {
            smartAccount = accountFactory.createAccount(investor);
        }

        uint256 tokens = calculateTokens(amount);

        // Mint tokens before transferring
        rwaToken.mint(address(this), tokens);

        require(
            rwaToken.transfer(smartAccount, tokens),
            "Token transfer failed"
        );

        investmentTimestamps[investor] = block.timestamp;

        emit InvestmentMade(investor, amount, tokens);
    }

    function initiateWithdrawal(
        address investor,
        uint256 tokens
    ) external onlyOwner whenNotPaused nonReentrant {
        require(
            block.timestamp >= investmentTimestamps[investor] + lockPeriod,
            "Lock period not over"
        );

        address smartAccount = accountFactory.getAccount(investor);
        require(smartAccount != address(0), "No investment found");

        uint256 fiatAmount = calculateFiatAmount(tokens);

        SmartAccount(smartAccount).burnTokens(address(rwaToken), tokens);

        emit WithdrawalInitiated(investor, fiatAmount, tokens);
    }

    function setLockPeriod(uint256 _lockPeriod) external onlyOwner {
        lockPeriod = _lockPeriod;
        emit LockPeriodChanged(_lockPeriod);
    }

    function calculateTokens(uint256 amount) internal view returns (uint256) {
        // Implement token calculation formula here
        return amount; // Placeholder implementation
    }

    function calculateFiatAmount(
        uint256 tokens
    ) internal view returns (uint256) {
        // Implement fiat amount calculation here
        return tokens; // Placeholder implementation
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
