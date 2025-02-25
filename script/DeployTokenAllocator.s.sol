// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "../../lib/forge-std/src/Script.sol";
import {TokenomicsManager} from "../../src/TokenomicsManager.sol";
import {ALLOToken} from "../../src/ALLOToken.sol";
import {TokenAllocator} from "../../src/TokenAllocator.sol";

contract DeployContracts is Script {
    // Set the deployer's address
    address deployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Anvil, first wallet address

    function run() external returns (TokenomicsManager, ALLOToken, TokenAllocator) {
        vm.startBroadcast();

        // Deploy TokenomicsManager
        TokenomicsManager tokenomicsManager = new TokenomicsManager(deployer);

        // Deploy ALLOToken
        ALLOToken alloToken = new ALLOToken(address(tokenomicsManager));

        // Deploy TokenAllocator
        TokenAllocator tokenAllocator = new TokenAllocator(address(tokenomicsManager), payable(address(alloToken)));

        vm.stopBroadcast();
        return (tokenomicsManager, alloToken, tokenAllocator);
    }
}
