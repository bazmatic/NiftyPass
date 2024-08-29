// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NiftyGate is ERC721, Ownable {
    uint256 private _nextTokenId;
    uint256 private _deletedCount;

    enum RuleType { OwnsCount, OwnsAnyOf, OwnsId }

    struct Rule {
        RuleType ruleType;
        address erc721Contract;
        uint256[] params; // Changed to array to accommodate multiple token IDs
    }

    struct Ruleset {
        bool isActive;
        uint256 ruleCount;
        mapping(uint256 => Rule) rules;
    }

    mapping(uint256 => Ruleset) private _rulesets;

    event RulesetCreated(uint256 indexed rulesetId, address owner);
    event RulesetRemoved(uint256 indexed rulesetId);
    event RuleAdded(uint256 indexed rulesetId, uint256 ruleIndex, RuleType ruleType, address erc721Contract, uint256[] params);
    event RuleRemoved(uint256 indexed rulesetId, uint256 ruleIndex);

    constructor(address initialOwner) ERC721("NiftyGate", "NFTG") Ownable(initialOwner) {
        _nextTokenId = 1;
        _deletedCount = 0;
    }

    modifier onlyRulesetOwner(uint256 _rulesetId) {
        require(ownerOf(_rulesetId) == msg.sender, "Not the owner of this ruleset");
        _;
    }

    modifier onlyActiveRuleset(uint256 _rulesetId) {
        require(_rulesets[_rulesetId].isActive, "Ruleset does not exist");
        _;
    }

    /**
     * @dev Create a new ruleset and mint a new NFT to authorise the bearer to administer it
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

    /**
     * @dev Remove a ruleset
     * @param _rulesetId The ID of the ruleset to remove
     */
   function removeRuleset(uint256 _rulesetId) external onlyRulesetOwner(_rulesetId) onlyActiveRuleset(_rulesetId) {
        _rulesets[_rulesetId].isActive = false;
        _deletedCount++;
        emit RulesetRemoved(_rulesetId);
    }

    function addRule(uint256 _rulesetId, RuleType _ruleType, address _erc721Contract, uint256[] calldata _params) external onlyRulesetOwner(_rulesetId) onlyActiveRuleset(_rulesetId) {
        uint256 newRuleIndex = _rulesets[_rulesetId].ruleCount;
        _rulesets[_rulesetId].rules[newRuleIndex] = Rule(_ruleType, _erc721Contract, _params);
        _rulesets[_rulesetId].ruleCount++;
        emit RuleAdded(_rulesetId, newRuleIndex, _ruleType, _erc721Contract, _params);
    }

    /**
     * @dev Remove a rule from a ruleset
     * @param _rulesetId The ID of the ruleset to remove the rule from
     * @param _ruleIndex The index of the rule to remove
     */
    function removeRule(uint256 _rulesetId, uint256 _ruleIndex) external onlyRulesetOwner(_rulesetId) {
        require(_ruleIndex < _rulesets[_rulesetId].ruleCount, "Rule does not exist");

        // If the rule is not the last rule, move the last rule to the position of the rule to be removed
        if (_ruleIndex < _rulesets[_rulesetId].ruleCount - 1) {
            _rulesets[_rulesetId].rules[_ruleIndex] = _rulesets[_rulesetId].rules[_rulesets[_rulesetId].ruleCount - 1];
        }
        _rulesets[_rulesetId].ruleCount--;

        emit RuleRemoved(_rulesetId, _ruleIndex);
    }

    /**
     * @dev Check if a user meets the requirements of a ruleset
     * @param _rulesetId The ID of the ruleset to check
     * @param _user The address of the user to check
     * @return True if the user meets the requirements of the ruleset
     */
    function checkRuleset(uint256 _rulesetId, address _user) external view onlyActiveRuleset(_rulesetId) returns (bool) {
        Ruleset storage ruleset = _rulesets[_rulesetId];
        for (uint i = 0; i < ruleset.ruleCount; i++) {
            if (!checkRule(_user, ruleset.rules[i])) {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev Check if a user meets the requirements of a rule
     * @param _user The address of the user to check
     * @param _rule The rule to check
     * @return True if the user meets the requirements of the rule
     */
    function checkRule(address _user, Rule memory _rule) internal view returns (bool) {
        IERC721 erc721 = IERC721(_rule.erc721Contract);
        uint256 balance = erc721.balanceOf(_user);

        // If the user does not own any tokens, they do not meet the rule
        if (balance == 0) {
            return false;
        }

        if (_rule.ruleType == RuleType.OwnsCount) {
            // The number of tokens is greater than or equal to the required number
            return balance >= _rule.params[0];
        } else if (_rule.ruleType == RuleType.OwnsId) {
            // The user owns the specified token
            try erc721.ownerOf(_rule.params[0]) returns (address owner) {
                return owner == _user;
            } catch {
                return false;
            }
        } else if (_rule.ruleType == RuleType.OwnsAnyOf) {
            // Check if the user owns any of the specified token IDs
            for (uint256 i = 0; i < _rule.params.length; i++) {
                try erc721.ownerOf(_rule.params[i]) returns (address owner) {
                    if (owner == _user) {
                        return true;
                    }
                } catch {
                    // If the token doesn't exist, continue to the next one
                    continue;
                }
            }
            return false;
        }

        return false;
    }

    /**
     * @dev Get the number of rulesets
     * @return The number of rulesets
     */
    function getRulesetCount() external view returns (uint256) {
        return _nextTokenId - _deletedCount - 1;
    }

    /**
     * @dev Get the IDs of all rules for a ruleset
     * @param _rulesetId The ID of the ruleset to get the rules for
     * @return An array of Rule structs
     */
    function getRulesetRules(uint256 _rulesetId) external view  onlyActiveRuleset(_rulesetId) returns (Rule[] memory) {    
        Ruleset storage ruleset = _rulesets[_rulesetId];
        Rule[] memory rules = new Rule[](ruleset.ruleCount);
        for (uint i = 0; i < ruleset.ruleCount; i++) {
            rules[i] = ruleset.rules[i];
        }
        return rules;
    }
}