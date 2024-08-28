// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {NiftyGate} from "../src/NiftyGate.sol";

contract NiftyGateScript is Script {
    NiftyGate public counter;

    function setUp() public {
        vm.startPrank(address(this));
    }

    function run() public {
        vm.startBroadcast();

        counter = new NiftyGate(address(this));

        vm.stopBroadcast();
    }
}
