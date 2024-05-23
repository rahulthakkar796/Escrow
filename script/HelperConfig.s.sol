// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    function deployERC20Mock() external returns (ERC20Mock) {
        vm.startBroadcast();
        ERC20Mock erc20Mock = new ERC20Mock();
        vm.stopBroadcast();
        return erc20Mock;
    }
}
