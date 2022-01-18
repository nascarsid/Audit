// /**
//  *@dev Contract created for development pupose only.
//  * keep on updating as per the requirements.
//  */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Vizva721 is ERC721Upgradeable, PausableUpgradeable, OwnableUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIds;

    function __VizvaToken_init(string memory _name, string memory _symbol) public initializer {
        __ERC721_init(_name, _symbol);
        __Ownable_init_unchained();
        __Pausable_init_unchained();
    }
    mapping (uint => string) internal uri;
    
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function createItem(string memory _uri)
        public whenNotPaused returns (uint256)
    {
         _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        _safeMint(msg.sender, tokenId);
        setURI(tokenId, _uri);

        return tokenId;
    }

    function setURI(uint256 tokenId, string memory _uri)
        internal
    {
        uri[tokenId] = _uri;
    }

    function tokenURI(uint256 tokenId)
        public
        view override
        returns (string memory)
    {
        return uri[tokenId];
    }
}