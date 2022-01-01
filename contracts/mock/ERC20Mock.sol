// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@rari-capital/solmate/src/tokens/ERC20.sol";

contract ERC20Mock is ERC20 {
    
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) ERC20(name, symbol, 18) {
        _mint(msg.sender, supply);
    }
}