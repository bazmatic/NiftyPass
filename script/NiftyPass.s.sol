// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {NiftyPass} from "../src/NiftyPass.sol";

contract NiftyPassScript is Script {
    NiftyPass public niftyPass;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        niftyPass = new NiftyPass(deployerAddress);

        vm.stopBroadcast();
    }
}