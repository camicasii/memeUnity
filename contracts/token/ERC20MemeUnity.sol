// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ERC20.sol";

// mock class using ERC20
contract ERC20MemeUnity is ERC20 {
    constructor () payable ERC20('Cami-memeUnity', 'meme') {
        uint totalSupply_ = 100000000 * 10 ** decimals();
        _mint(msg.sender, totalSupply_);
    }
/*
    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }


    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }
*/

    function transferInternal(address from, address to, uint256 value) public {
        _transfer(from, to, value);
    }

    function approveInternal(address owner, address spender, uint256 value) public {
        _approve(owner, spender, value);
    }
}
