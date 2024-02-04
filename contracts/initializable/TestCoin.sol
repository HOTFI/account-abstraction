// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestCoin is ERC20 {

    constructor() ERC20("Test Coin", "TC") {
    }

    function mint() external{
        _mint(_msgSender(), 1000 ether);
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}