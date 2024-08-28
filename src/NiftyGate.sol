// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NiftyGate is ERC721, Ownable {
    uint256 private _nextTokenId;

    enum RuleType { OwnsCount, OwnsAnyOf, OwnsId }

    struct Rule {
        RuleType ruleType;
        address erc721Contract;
        uint256 param1;
        uint256 param2;
    }

    struct Ruleset {
        bool isActive;
        uint256 ruleCount;
        mapping(uint256 => Rule) rules;
    }

    mapping(uint256 => Ruleset) private _rulesets;

    event RulesetCreated(uint256 indexed rulesetId, address owner);
    event RulesetRemoved(uint256 indexed rulesetId);
    event RuleAdded(uint256 indexed rulesetId, uint256 ruleIndex, RuleType ruleType, address erc721Contract, uint256 param1, uint256 param2);
    event RuleRemoved(uint256 indexed rulesetId, uint256 ruleIndex);

    constructor(address initialOwner) ERC721("NiftyGate", "NFTG") Ownable(initialOwner) {
        _nextTokenId = 1;
    }

    modifier onlyRulesetOwner(uint256 _rulesetId) {
        require(ownerOf(_rulesetId) == msg.sender, "Not the owner of this ruleset");
        _;
    }

    modifier onlyActiveRuleset(uint256 _rulesetId) {
        require(_rulesets[_rulesetId].isActive, "Ruleset is not active");
        _;
    }

    /**
     * Create a new ruleset and mint a new NFT to authorise the bearer to administer it
     */
    function createRuleset() external returns (uint256) {
        uint256 newRulesetId = _nextTokenId;

        Ruleset storage newRuleset = _rulesets[newRulesetId];
        newRuleset.isActive = true;
        newRuleset.ruleCount = 0;

        _safeMint(msg.sender, newRulesetId);
        _nextTokenId ++;

        emit RulesetCreated(newRulesetId, msg.sender);
        return newRulesetId;
    }

   function removeRuleset(uint256 _rulesetId) external onlyRulesetOwner(_rulesetId) onlyActiveRuleset(_rulesetId) {
        _rulesets[_rulesetId].isActive = false;
        emit RulesetRemoved(_rulesetId);
    }

    function addRule(uint256 _rulesetId, RuleType _ruleType, address _erc721Contract, uint256 _param1, uint256 _param2) external onlyRulesetOwner(_rulesetId) onlyActiveRuleset(_rulesetId) {
        uint256 newRuleIndex = _rulesets[_rulesetId].ruleCount;
        _rulesets[_rulesetId].rules[newRuleIndex] = Rule(_ruleType, _erc721Contract, _param1, _param2);
        _rulesets[_rulesetId].ruleCount++;
        emit RuleAdded(_rulesetId, newRuleIndex, _ruleType, _erc721Contract, _param1, _param2);
    }

    function removeRule(uint256 _rulesetId, uint256 _ruleIndex) external onlyRulesetOwner(_rulesetId) {
        require(_ruleIndex < _rulesets[_rulesetId].ruleCount, "Rule does not exist");

        if (_ruleIndex < _rulesets[_rulesetId].ruleCount - 1) {
            _rulesets[_rulesetId].rules[_ruleIndex] = _rulesets[_rulesetId].rules[_rulesets[_rulesetId].ruleCount - 1];
        }
        _rulesets[_rulesetId].ruleCount--;

        emit RuleRemoved(_rulesetId, _ruleIndex);
    }

    function checkRuleset(uint256 _rulesetId, address _user) external view onlyActiveRuleset(_rulesetId) returns (bool) {
        Ruleset storage ruleset = _rulesets[_rulesetId];
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
        return _nextTokenId - 1;
    }

    function getActiveRulesets() external view returns (uint256[] memory) {
        uint256 totalRulesets = _nextTokenId - 1;
        uint256 activeCount = 0;
        
        for (uint256 i = 1; i <= totalRulesets; i++) {
            if (_rulesets[i].isActive) {
                activeCount++;
            }
        }

        uint256[] memory activeRulesetIds = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 1; i <= totalRulesets; i++) {
            if (_rulesets[i].isActive) {
                activeRulesetIds[index] = i;
                index++;
            }
        }

        return activeRulesetIds;
    }

    function getRulesetRules(uint256 _rulesetId) external view returns (Rule[] memory) {
        require(_rulesets[_rulesetId].isActive, "Ruleset is not active");
        Ruleset storage ruleset = _rulesets[_rulesetId];
        Rule[] memory rules = new Rule[](ruleset.ruleCount);
        for (uint i = 0; i < ruleset.ruleCount; i++) {
            rules[i] = ruleset.rules[i];
        }
        return rules;
    }
}