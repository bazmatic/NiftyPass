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

contract NiftyGateTest is Test {
    NiftyGate public niftyGate;
    MockERC721 public mockNFT;
    address public owner = address(1);
    address public user = address(2);
    address public user2 = address(3);

    function setUp() public {
        vm.startPrank(owner);
        niftyGate = new NiftyGate(owner);
        mockNFT = new MockERC721();
        vm.stopPrank();
    }

    function testCreateRuleset() public {
        vm.prank(owner);
        uint256 rulesetId = niftyGate.createRuleset();
        assertEq(niftyGate.getRulesetCount(), 1);
        assertEq(niftyGate.ownerOf(rulesetId), owner);
    }

    function testAddRule() public {
        vm.startPrank(owner);
        uint256 rulesetId = niftyGate.createRuleset();
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsCount, address(mockNFT), 1, 100);
        NiftyGate.Rule[] memory rules = niftyGate.getRulesetRules(rulesetId);
        assertEq(rules.length, 1);
        assertEq(uint(rules[0].ruleType), uint(NiftyGate.RuleType.OwnsCount));
        vm.stopPrank();
    }

    function testCheckRuleset() public {
        vm.startPrank(owner);
        uint256 rulesetId = niftyGate.createRuleset();
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsCount, address(mockNFT), 1, 100);
        vm.stopPrank();

        mockNFT.mint(user, 1);
        
        bool result = niftyGate.checkRuleset(rulesetId, user);
        assertTrue(result);
    }

    function testRemoveRule() public {
        vm.startPrank(owner);
        uint256 rulesetId = niftyGate.createRuleset();
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsCount, address(mockNFT), 1, 100);
        niftyGate.removeRule(rulesetId, 0);
        NiftyGate.Rule[] memory rules = niftyGate.getRulesetRules(rulesetId);
        assertEq(rules.length, 0);
        vm.stopPrank();
    }

    function testRemoveRuleset() public {
        vm.startPrank(owner);
        uint256 rulesetId = niftyGate.createRuleset();
        niftyGate.removeRuleset(rulesetId);
        uint256[] memory activeRulesetIds = niftyGate.getActiveRulesets();
        assertEq(activeRulesetIds.length, 0);
        vm.stopPrank();
    }

    function testOnlyOwnerCanModifyRuleset() public {
        vm.prank(owner);
        uint256 rulesetId = niftyGate.createRuleset();

        vm.expectRevert("Not the owner of this ruleset");
        vm.prank(user);
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsCount, address(mockNFT), 1, 100);

        vm.expectRevert("Not the owner of this ruleset");
        vm.prank(user);
        niftyGate.removeRuleset(rulesetId);
    }

    function testTransferRulesetOwnership() public {
        vm.prank(owner);
        uint256 rulesetId = niftyGate.createRuleset();

        vm.prank(owner);
        niftyGate.transferFrom(owner, user, rulesetId);

        assertEq(niftyGate.ownerOf(rulesetId), user);

        vm.prank(user);
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsCount, address(mockNFT), 1, 100);

        vm.expectRevert("Not the owner of this ruleset");
        vm.prank(owner);
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsCount, address(mockNFT), 1, 100);
    }

    function testMultipleRulesets() public {
        vm.startPrank(owner);
        uint256 rulesetId1 = niftyGate.createRuleset();
        uint256 rulesetId2 = niftyGate.createRuleset();
        assertEq(niftyGate.getRulesetCount(), 2);
        assertEq(niftyGate.ownerOf(rulesetId1), owner);
        assertEq(niftyGate.ownerOf(rulesetId2), owner);
        vm.stopPrank();

        assertEq(niftyGate.getRulesetCount(), 2);
    }

    function testCheckRulesetWithMultipleRules() public {
        vm.startPrank(owner);
        uint256 rulesetId = niftyGate.createRuleset();
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsCount, address(mockNFT), 2, 100);
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsId, address(mockNFT), 5, 0);
        vm.stopPrank();

        mockNFT.mint(user, 1);
        mockNFT.mint(user, 2);
        
        bool result = niftyGate.checkRuleset(rulesetId, user);
        assertFalse(result); // User doesn't own token ID 5

        mockNFT.mint(user, 5);
        result = niftyGate.checkRuleset(rulesetId, user);
        assertTrue(result); // Now user satisfies both rules
    }

    function testRuleTypes() public {
        vm.startPrank(owner);
        uint256 rulesetId = niftyGate.createRuleset();
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsCount, address(mockNFT), 2, 100);
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsAnyOf, address(mockNFT), 5, 10);
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsId, address(mockNFT), 15, 0);
        vm.stopPrank();

        mockNFT.mint(user, 1);
        mockNFT.mint(user, 2);
        mockNFT.mint(user, 7);
        mockNFT.mint(user, 15);

        bool result = niftyGate.checkRuleset(rulesetId, user);
        assertTrue(result); // User satisfies all three rule types
    }

    function testGetActiveRulesets() public {
        vm.startPrank(owner);
        uint256 rulesetId1 = niftyGate.createRuleset(); 
        uint256 rulesetId2 = niftyGate.createRuleset();
        uint256 rulesetId3 = niftyGate.createRuleset(); 
        niftyGate.removeRuleset(rulesetId2);
        vm.stopPrank();

        uint256[] memory activeRulesets = niftyGate.getActiveRulesets();
        assertEq(activeRulesets.length, 2);
        assertEq(activeRulesets[0], rulesetId1);
        assertEq(activeRulesets[1], rulesetId3);
    }

    function testRulesetActivation() public {
        vm.startPrank(owner);
        uint256 rulesetId = niftyGate.createRuleset();
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsCount, address(mockNFT), 1, 100);
        niftyGate.removeRuleset(rulesetId);
        vm.stopPrank();

        mockNFT.mint(user, 1);

        vm.expectRevert("Ruleset is not active");
        niftyGate.checkRuleset(rulesetId, user);
    }
}