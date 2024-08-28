// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/NiftyGate.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    constructor() ERC721("MockToken", "MTK") {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}

contract ERC721MultiRulesetTest is Test {
    NiftyGate public niftyGate;
    MockERC721 public mockNFT;
    address public owner = address(1);
    address public user = address(2);

    function setUp() public {
        vm.startPrank(owner);
        niftyGate = new NiftyGate(owner);
        mockNFT = new MockERC721();
        vm.stopPrank();
    }

    function testCreateRuleset() public {
        vm.prank(owner);
        niftyGate.createRuleset("Test Ruleset");
        assertEq(niftyGate.getRulesetCount(), 1);
    }

    function testAddRule() public {
        vm.startPrank(owner);
        niftyGate.createRuleset("Test Ruleset");
        niftyGate.addRule(0, NiftyGate.RuleType.OwnsCount, address(mockNFT), 1, 100);
        NiftyGate.Rule[] memory rules = niftyGate.getRulesetRules(0);
        assertEq(rules.length, 1);
        assertEq(uint(rules[0].ruleType), uint(NiftyGate.RuleType.OwnsCount));
        vm.stopPrank();
    }

    function testCheckRulesetPass() public {
        vm.startPrank(owner);
        niftyGate.createRuleset("Test Ruleset");
        niftyGate.addRule(0, NiftyGate.RuleType.OwnsCount, address(mockNFT), 1, 100);
        vm.stopPrank();

        mockNFT.mint(user, 1);
        
        bool result = niftyGate.checkRuleset(0, user);
        assertTrue(result);
    }

    function testCheckRulesetFail() public {
        vm.startPrank(owner);
        niftyGate.createRuleset("Test Ruleset");
        niftyGate.addRule(0, NiftyGate.RuleType.OwnsCount, address(mockNFT), 1, 100);
        vm.stopPrank();

        bool result = niftyGate.checkRuleset(0, user);
        assertFalse(result);
    }   

    function testRemoveRule() public {
        vm.startPrank(owner);
        niftyGate.createRuleset("Test Ruleset");
        niftyGate.addRule(0, NiftyGate.RuleType.OwnsCount, address(mockNFT), 1, 100);
        niftyGate.removeRule(0, 0);
        NiftyGate.Rule[] memory rules = niftyGate.getRulesetRules(0);
        assertEq(rules.length, 0);
        vm.stopPrank();
    }

    function testRemoveRuleset() public {
        vm.startPrank(owner);
        niftyGate.createRuleset("Test Ruleset");
        niftyGate.removeRuleset(0);
        uint256[] memory activeRulesetIds = niftyGate.getActiveRulesets();
        assertEq(activeRulesetIds.length, 0);
        vm.stopPrank();
    }
}