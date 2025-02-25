// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/manager/AccessManager.sol";

/**
 * @title Allostasi Tokenomic Manager
 * @author Centeria Team
 * @notice This contract manages all the access in the Allostasis tokenomic
 */
contract TokenomicsManager is AccessManager {
    constructor(address initialAdmin) AccessManager(initialAdmin) {}
}
