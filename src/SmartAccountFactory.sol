// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./SmartAccount.sol";

contract SmartAccountFactory is Ownable {
    mapping(address => address) public userAccounts;
    address public rwaToken;
    address public investmentManager;

    event AccountCreated(address indexed user, address account);

    constructor(address _rwaToken) Ownable(msg.sender) {
        rwaToken = _rwaToken;
    }

    function setInvestmentManager(
        address _investmentManager
    ) external onlyOwner {
        investmentManager = _investmentManager;
    }

    function createAccount(address user) external returns (address) {
        require(
            msg.sender == investmentManager,
            "Only InvestmentManager can create accounts"
        );
        require(userAccounts[user] == address(0), "Account already exists");

        SmartAccount newAccount = new SmartAccount(user, rwaToken);
        userAccounts[user] = address(newAccount);

        emit AccountCreated(user, address(newAccount));
        return address(newAccount);
    }

    function getAccount(address user) external view returns (address) {
        return userAccounts[user];
    }
}
