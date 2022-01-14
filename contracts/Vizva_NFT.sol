// /**
//  *@dev Contract created for development pupose only.
//  * keep on updating as per the requirements.
//  */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract VizvaToken is ERC721, Pausable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("VIZVA TOKEN", "VIZVA") {}

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