//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ERC721NFT} from "./VizvaERC721NFT.sol";

contract VizvaCollectionClone is Ownable {
    address immutable ERC721CollectionImplementation;
    address private marketAddress;

    event NewERC721CollectionCreated(
        address clone,
        address owner,
        string name,
        string symbol
    );

    constructor(address _marketAddress) {
        ERC721CollectionImplementation = address(new ERC721NFT());
        marketAddress = _marketAddress;
    }

    function createERC721Collection(
        string calldata name,
        string calldata symbol
    ) external virtual returns (address) {
        address clone = Clones.clone(ERC721CollectionImplementation);
        ERC721NFT(clone).__ERC721NFT_init(
            name,
            symbol,
            _msgSender(),
            marketAddress
        );
        emit NewERC721CollectionCreated(clone, msg.sender, name, symbol);
        return clone;
    }

    function setMarketAddress(address _newAddress) public virtual onlyOwner {
        marketAddress = _newAddress;
    }

    function getMarketAddress() public view virtual returns (address) {
        return marketAddress;
    }
}
