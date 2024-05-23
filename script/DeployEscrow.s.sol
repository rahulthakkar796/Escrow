// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Escrow} from "../src/Escrow.sol";

contract DeployEscrow is Script {
    function run(address arbitrator) external returns (Escrow) {
        vm.startBroadcast();
        Escrow escrow = new Escrow(arbitrator);
        vm.stopBroadcast();
        return escrow;
    }
}
