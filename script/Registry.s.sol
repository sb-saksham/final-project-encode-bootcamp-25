// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Registry} from "../src/Registry.sol";

contract RegistryScript is Script {
    Registry public Registry;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        Registry = new Registry();

        vm.stopBroadcast();
    }
}
