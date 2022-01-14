// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Vizva1155contract is ERC1155, Ownable, Pausable, ERC1155Burnable, ERC1155Supply {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    mapping(uint256 => string) private _uris;


    constructor(
        string memory name, 
        string memory symbol
    ) ERC1155("") {

        bytes memory tempName = bytes(name); // Uses memory
        bytes memory tempSymbol = bytes(symbol);
        require( tempName.length != 0 && tempSymbol.length != 0,
            "ERC1155: Choose a name and symbol");
    }

    function setURI(uint256 tokenId, string memory newuri) internal {
        // _setURI(newuri);
        _uris[tokenId] = newuri;
    }

    function uri(uint256 tokenId) override public view returns (string memory) {
        return(_uris[tokenId]);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address _account, uint256 _amount, string memory _uri)
        public whenNotPaused returns(uint256, uint256)
    {

        //Effects
        uint256 _id = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        //Interaction
        _mint(_account, _id, _amount, "");
        setURI(_id, _uri);
        return(_id, _amount);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
    {
        _mintBatch(to, ids, amounts, data);
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override(ERC1155, ERC1155Supply)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}