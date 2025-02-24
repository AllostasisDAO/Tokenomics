// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/manager/AccessManaged.sol";

/**
 * @title Allostasis DAO token
 * @author Centeria Team
 */
contract ALLOToken is ERC20, ERC20Pausable, AccessManaged {

    uint256 private constant MAX_SUPPLY = 10_000_000_000 * 10**18;

    constructor(address initialAuthority)
        ERC20("ALLOToken", "ALLO")
        AccessManaged(initialAuthority)
    {}

    function pause() public restricted {
        _pause();
    }

    function unpause() public restricted {
        _unpause();
    }

    function mint(address to, uint256 amount) public payable restricted {
        require(totalSupply() + amount <= MAX_SUPPLY, "Minting would exceed the maximum supply");
        _mint(to, amount);
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
        internal override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }
}