// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract RWAToken is ERC20, Ownable, Pausable {
    address public minter;

    event MinterChanged(address indexed newMinter);

    constructor() ERC20("RWA Investment Token", "RWA") Ownable(msg.sender) {
        minter = msg.sender;
    }

    function setMinter(address _minter) external onlyOwner {
        require(_minter != address(0), "Invalid minter address");
        minter = _minter;
        emit MinterChanged(_minter);
    }

    function mint(address to, uint256 amount) external whenNotPaused {
        require(msg.sender == minter, "Only minter can mint");
        _mint(to, amount);
    }

    function batchMint(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external whenNotPaused {
        require(msg.sender == minter, "Only minter can mint");
        require(
            recipients.length == amounts.length,
            "Arrays must have same length"
        );

        for (uint i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
        }
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
