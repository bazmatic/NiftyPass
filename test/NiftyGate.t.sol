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
        uint256[] memory params = new uint256[](1);
        params[0] = 1;
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsCount, address(mockNFT), params);
        NiftyGate.Rule[] memory rules = niftyGate.getRulesetRules(rulesetId);
        assertEq(rules.length, 1);
        assertEq(uint(rules[0].ruleType), uint(NiftyGate.RuleType.OwnsCount));
        vm.stopPrank();
    }

    function testCheckRuleset() public {
        vm.startPrank(owner);

        uint256 rulesetId = niftyGate.createRuleset();
        uint256[] memory params = new uint256[](1);
        params[0] = 2;
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsCount, address(mockNFT), params);

        mockNFT.mint(user, 1);

        bool result = niftyGate.checkRuleset(rulesetId, user);
        assertFalse(result);

        mockNFT.mint(user, 2);
        result = niftyGate.checkRuleset(rulesetId, user);
        assertTrue(result);

        vm.stopPrank();
    }

    function testRemoveRule() public {
        vm.startPrank(owner);

        uint256 rulesetId = niftyGate.createRuleset();
        uint256[] memory params = new uint256[](1);
        params[0] = 1;
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsCount, address(mockNFT), params);
        niftyGate.removeRule(rulesetId, 0);
        NiftyGate.Rule[] memory rules = niftyGate.getRulesetRules(rulesetId);
        assertEq(rules.length, 0);

        vm.stopPrank();
    }

    function testRemoveRuleset() public {
        vm.startPrank(owner);

        uint256 rulesetId = niftyGate.createRuleset();
        niftyGate.removeRuleset(rulesetId);
        assertEq(niftyGate.getRulesetCount(), 0);

        vm.expectRevert("Ruleset does not exist");
        niftyGate.getRulesetRules(rulesetId);

        vm.stopPrank();
    }

    function testOnlyOwnerCanModifyRuleset() public {
        vm.prank(owner);
        uint256 rulesetId = niftyGate.createRuleset();

        uint256[] memory params = new uint256[](1);
        params[0] = 1;

        vm.expectRevert("Not the owner of this ruleset");
        vm.prank(user);
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsCount, address(mockNFT), params);

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

        uint256[] memory params = new uint256[](1);
        params[0] = 1;

        vm.prank(user);
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsCount, address(mockNFT), params);

        vm.expectRevert("Not the owner of this ruleset");
        vm.prank(owner);
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsCount, address(mockNFT), params);
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

   function testOwnsCountOfRule() public {
        vm.startPrank(owner);
        uint256 rulesetId = niftyGate.createRuleset();
        uint256[] memory params = new uint256[](4);
        params[0] = 2; // Require ownership of 2 tokens from the list
        params[1] = 5;
        params[2] = 10;
        params[3] = 15;
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsCountOf, address(mockNFT), params);
        vm.stopPrank();

        mockNFT.mint(user, 1);
        mockNFT.mint(user, 5);
        
        bool result = niftyGate.checkRuleset(rulesetId, user);
        assertFalse(result); // User only owns 1 token from the list, needs 2

        mockNFT.mint(user, 10);
        result = niftyGate.checkRuleset(rulesetId, user);
        assertTrue(result); // Now user owns 2 tokens from the list

        mockNFT.mint(user, 15);
        result = niftyGate.checkRuleset(rulesetId, user);
        assertTrue(result); // User still meets the criteria
    }

    function testCheckRulesetWithMultipleRules() public {
        vm.startPrank(owner);
        uint256 rulesetId = niftyGate.createRuleset();
        
        uint256[] memory countParams = new uint256[](1);
        countParams[0] = 2;
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsCount, address(mockNFT), countParams);
        
        uint256[] memory idParams = new uint256[](1);
        idParams[0] = 5;
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsId, address(mockNFT), idParams);
        vm.stopPrank();

        mockNFT.mint(user, 1);
        mockNFT.mint(user, 2);

        bool result = niftyGate.checkRuleset(rulesetId, user);
        assertFalse(result); // User doesn't own token ID 5

        mockNFT.mint(user, 5);
        result = niftyGate.checkRuleset(rulesetId, user);
        assertTrue(result); // Now user satisfies both rules
    }

    function testOwnsCountRule() public {
        vm.startPrank(owner);
        uint256 rulesetId = niftyGate.createRuleset();
        uint256[] memory params = new uint256[](1);
        params[0] = 2;
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsCount, address(mockNFT), params);
        vm.stopPrank();

        mockNFT.mint(user, 1);
        mockNFT.mint(user, 2);

        bool result = niftyGate.checkRuleset(rulesetId, user);
        assertTrue(result);
    }

    function testOwnsIdRule() public {
        vm.startPrank(owner);
        uint256 rulesetId = niftyGate.createRuleset();
        uint256[] memory params = new uint256[](1);
        params[0] = 5;
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsId, address(mockNFT), params);
        vm.stopPrank();

        mockNFT.mint(user, 5);

        bool result = niftyGate.checkRuleset(rulesetId, user);
        assertTrue(result);
    }

    function testRuleTypes() public {
        vm.startPrank(owner);
        uint256 rulesetId = niftyGate.createRuleset();

        uint256[] memory countParams = new uint256[](1);
        countParams[0] = 2;
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsCount, address(mockNFT), countParams);

        uint256[] memory countOfParams = new uint256[](4);
        countOfParams[0] = 2; // Require ownership of 2 tokens from the list
        countOfParams[1] = 5;
        countOfParams[2] = 7;
        countOfParams[3] = 10;
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsCountOf, address(mockNFT), countOfParams);

        uint256[] memory idParams = new uint256[](1);
        idParams[0] = 15;
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsId, address(mockNFT), idParams);
        vm.stopPrank();

        mockNFT.mint(user, 1);
        mockNFT.mint(user, 2);
        mockNFT.mint(user, 5);
        mockNFT.mint(user, 7);
        mockNFT.mint(user, 15);

        bool result = niftyGate.checkRuleset(rulesetId, user);
        assertTrue(result); // User satisfies all three rule types
    }

    function testRulesetActivation() public {
        vm.startPrank(owner);
        uint256 rulesetId = niftyGate.createRuleset();
        uint256[] memory params = new uint256[](1);
        params[0] = 1;
        niftyGate.addRule(rulesetId, NiftyGate.RuleType.OwnsCount, address(mockNFT), params);
        niftyGate.removeRuleset(rulesetId);
        vm.stopPrank();

        mockNFT.mint(user, 1);

        vm.expectRevert("Ruleset does not exist");
        niftyGate.checkRuleset(rulesetId, user);
    }
}