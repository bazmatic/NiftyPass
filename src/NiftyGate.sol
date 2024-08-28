// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NiftyGate is Ownable {
    constructor(address initialOwner) Ownable(initialOwner) {}

    enum RuleType { OwnsCount, OwnsAnyOf, OwnsId }

    struct Rule {
        RuleType ruleType;
        address erc721Contract;
        uint256 param1;
        uint256 param2;
    }

    struct Ruleset {
        string name;
        bool isActive;
        uint256 ruleCount;
        mapping(uint256 => Rule) rules;
    }

    mapping(uint256 => Ruleset) public rulesets;
    uint256 public rulesetCount;

    event RulesetCreated(uint256 indexed rulesetId, string name);
    event RulesetRemoved(uint256 indexed rulesetId);
    event RuleAdded(uint256 indexed rulesetId, uint256 ruleIndex, RuleType ruleType, address erc721Contract, uint256 param1, uint256 param2);
    event RuleRemoved(uint256 indexed rulesetId, uint256 ruleIndex);

    function createRuleset(string memory _name) external onlyOwner {
        uint256 newRulesetId = rulesetCount;
        Ruleset storage newRuleset = rulesets[newRulesetId];
        newRuleset.name = _name;
        newRuleset.isActive = true;
        newRuleset.ruleCount = 0;
        rulesetCount++;
        emit RulesetCreated(newRulesetId, _name);
    }

    function removeRuleset(uint256 _rulesetId) external onlyOwner {
        require(_rulesetId < rulesetCount, "Ruleset does not exist");
        rulesets[_rulesetId].isActive = false;
        emit RulesetRemoved(_rulesetId);
    }

    function addRule(uint256 _rulesetId, RuleType _ruleType, address _erc721Contract, uint256 _param1, uint256 _param2) external onlyOwner {
        require(_rulesetId < rulesetCount, "Ruleset does not exist");
        require(rulesets[_rulesetId].isActive, "Ruleset is not active");

        uint256 newRuleIndex = rulesets[_rulesetId].ruleCount;
        rulesets[_rulesetId].rules[newRuleIndex] = Rule(_ruleType, _erc721Contract, _param1, _param2);
        rulesets[_rulesetId].ruleCount++;
        emit RuleAdded(_rulesetId, newRuleIndex, _ruleType, _erc721Contract, _param1, _param2);
    }

    function removeRule(uint256 _rulesetId, uint256 _ruleIndex) external onlyOwner {
        require(_rulesetId < rulesetCount, "Ruleset does not exist");
        require(_ruleIndex < rulesets[_rulesetId].ruleCount, "Rule does not exist");

        // Move the last element to the place of the removed one
        if (_ruleIndex < rulesets[_rulesetId].ruleCount - 1) {
            rulesets[_rulesetId].rules[_ruleIndex] = rulesets[_rulesetId].rules[rulesets[_rulesetId].ruleCount - 1];
        }
        rulesets[_rulesetId].ruleCount--;

        emit RuleRemoved(_rulesetId, _ruleIndex);
    }

    function checkRuleset(uint256 _rulesetId, address _user) external view returns (bool) {
        require(_rulesetId < rulesetCount, "Ruleset does not exist");
        require(rulesets[_rulesetId].isActive, "Ruleset is not active");

        Ruleset storage ruleset = rulesets[_rulesetId];
        for (uint i = 0; i < ruleset.ruleCount; i++) {
            if (!checkRule(_user, ruleset.rules[i])) {
                return false;
            }
        }
        return true;
    }

    function checkRule(address _user, Rule memory _rule) internal view returns (bool) {
        IERC721 erc721 = IERC721(_rule.erc721Contract);

        if (_rule.ruleType == RuleType.OwnsCount) {
            uint256 count = 0;
            for (uint256 i = 0; i < _rule.param2; i++) {
                try erc721.ownerOf(i) returns (address owner) {
                    if (owner == _user) {
                        count++;
                        if (count >= _rule.param1) {
                            return true;
                        }
                    }
                } catch {
                    // Token doesn't exist or other error, continue to next token
                }
            }
            return false;
        } else if (_rule.ruleType == RuleType.OwnsAnyOf) {
            for (uint256 i = _rule.param1; i <= _rule.param2; i++) {
                try erc721.ownerOf(i) returns (address owner) {
                    if (owner == _user) {
                        return true;
                    }
                } catch {
                    // Token doesn't exist or other error, continue to next token
                }
            }
            return false;
        } else if (_rule.ruleType == RuleType.OwnsId) {
            try erc721.ownerOf(_rule.param1) returns (address owner) {
                return owner == _user;
            } catch {
                return false;
            }
        }

        return false;
    }

    function getRulesetCount() external view returns (uint256) {
        return rulesetCount;
    }

    function getActiveRulesets() external view returns (uint256[] memory) {
        uint256 activeCount = 0;
        for (uint i = 0; i < rulesetCount; i++) {
            if (rulesets[i].isActive) {
                activeCount++;
            }
        }

        uint256[] memory activeRulesetIds = new uint256[](activeCount);
        uint256 index = 0;
        for (uint i = 0; i < rulesetCount; i++) {
            if (rulesets[i].isActive) {
                activeRulesetIds[index] = i;
                index++;
            }
        }

        return activeRulesetIds;
    }

    function getRulesetRules(uint256 _rulesetId) external view returns (Rule[] memory) {
        require(_rulesetId < rulesetCount, "Ruleset does not exist");
        Ruleset storage ruleset = rulesets[_rulesetId];
        Rule[] memory rules = new Rule[](ruleset.ruleCount);
        for (uint i = 0; i < ruleset.ruleCount; i++) {
            rules[i] = ruleset.rules[i];
        }
        return rules;
    }
}