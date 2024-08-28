// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {NiftyGate} from "../src/NiftyGate.sol";

contract NiftyGateScript is Script {
    NiftyGate public niftyGate;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        niftyGate = new NiftyGate(deployerAddress);

        vm.stopBroadcast();
    }
}