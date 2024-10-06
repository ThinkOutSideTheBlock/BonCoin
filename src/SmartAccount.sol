// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SmartAccount {
    using SafeERC20 for IERC20;

    address public owner;
    address public rwaToken;
    address public investmentManager;

    event TokensBurned(uint256 amount);

    constructor(address _owner, address _rwaToken) {
        owner = _owner;
        rwaToken = _rwaToken;
    }

    function setInvestmentManager(address _investmentManager) external {
        require(msg.sender == owner, "Only owner can set InvestmentManager");
        investmentManager = _investmentManager;
    }

    function burnTokens(address token, uint256 amount) external {
        require(msg.sender == investmentManager, "Only InvestmentManager can burn tokens");
        require(token == rwaToken, "Can only burn RWA tokens");
        
        IERC20(token).safeTransfer(address(0xdead), amount);
        emit TokensBurned(amount);
    }

    function withdrawTokens(address token, uint256 amount) external {
        require(msg.sender == owner, "Only owner can withdraw");
        IERC20(token).safeTransfer(owner, amount);
    }
}
