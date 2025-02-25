// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "../../lib/forge-std/src/Script.sol";
import {TokenomicsManager} from "../../src/TokenomicsManager.sol";
import {ALLOToken} from "../../src/ALLOToken.sol";
import {TokenAllocator} from "../../src/TokenAllocator.sol";
import {StockSlipsAllo} from "../src/ssAlloToken.sol";
import {PlatformsAllocator} from "../src/PlatformsAllocator.sol";

contract DeployContracts is Script {

    function run() external returns (TokenomicsManager, ALLOToken, TokenAllocator) {
        vm.startBroadcast();

        // Deploy TokenomicsManager
        TokenomicsManager tokenomicsManager = new TokenomicsManager(msg.sender);

        // Deploy ALLOToken
        ALLOToken alloToken = new ALLOToken(address(tokenomicsManager));

        // Deploy TokenAllocator
        TokenAllocator tokenAllocator = new TokenAllocator(address(tokenomicsManager), payable(address(alloToken)));

        // Deploy ssAlloToken
        StockSlipsAllo ssAlloToken =
            new StockSlipsAllo(address(tokenomicsManager), address(tokenAllocator), payable(address(alloToken)));

        // Deploy PlatformAllocator
        PlatformsAllocator platformsAllocator = new TokenAllocator(address(tokenomicsManager), payable(address(alloToken)));

        vm.stopBroadcast();
        return (tokenomicsManager, alloToken, tokenAllocator, ssAlloToken, platformsAllocator);
    }
}
