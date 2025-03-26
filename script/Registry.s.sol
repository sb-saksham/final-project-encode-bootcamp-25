// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PropertyRegistry} from "../src/Registry.sol";

contract PropertyRegistryScript is Script {
    PropertyRegistry public propertyRegistry;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        propertyRegistry = new PropertyRegistry();

        vm.stopBroadcast();
    }
}
