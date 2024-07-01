// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721RoyaltyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Rewards1167 is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    ERC721PausableUpgradeable,
    AccessControlUpgradeable,
    ERC721BurnableUpgradeable,
    ERC721RoyaltyUpgradeable
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bool public blocked;

    error Rewards1167__RoyaltyTooHigh();

    /*
    /// @custom:oz-upgrades-unsafe-allow constructor

    */

    constructor(
        address payable treasury,
        uint16 royalty,
        string memory name,
        string memory symbol,
        address contractOnwer
    ) {
        initialize(treasury, royalty, name, symbol, contractOnwer);
    }

    function initialize(
        address payable treasury,
        uint16 royalty,
        string memory name,
        string memory symbol,
        address contractOnwer
    )
        public
        initializer
    {
        if (royalty > 2500) revert Rewards1167__RoyaltyTooHigh();
        __ERC721_init(name, symbol);
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __ERC721Pausable_init();
        __AccessControl_init();
        __ERC721Burnable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, contractOnwer);
        _grantRole(PAUSER_ROLE, contractOnwer);
        _grantRole(MINTER_ROLE, contractOnwer);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(URI_SETTER_ROLE, contractOnwer);
        _setDefaultRoyalty(payable(treasury), royalty);
        blocked = false;
    }

    function setRoyalty(address payable treasury, uint96 feeNumerator) public onlyRole(DEFAULT_ADMIN_ROLE) {
        //onlyRole(MINTER_ROLE)
        _setDefaultRoyalty(payable(treasury), feeNumerator); //feeNumerator 100 is 1%, 2500 is 25% and 10000 is 100%
    }

    function toBlock() public onlyRole(MINTER_ROLE) {
        blocked = true;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function safeMint(address to, uint256 tokenId, string memory uri) public onlyRole(MINTER_ROLE) {
        // cannot require block here otherwise we cannot mint rewards
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function setTokenURI(uint256 tokenId, string memory uri) public onlyRole(URI_SETTER_ROLE) {
        _setTokenURI(tokenId, uri);
    }

    // The following functions are overrides required by Solidity.
    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721PausableUpgradeable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(
        address account,
        uint128 value
    )
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(
            ERC721Upgradeable,
            ERC721EnumerableUpgradeable,
            ERC721URIStorageUpgradeable,
            AccessControlUpgradeable,
            ERC721RoyaltyUpgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
