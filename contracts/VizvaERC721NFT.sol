//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC721URIStorageUpgradeable, ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {CountersUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract ERC721NFT is ERC721URIStorageUpgradeable, AccessControlUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIds;

    // Maximum number of token that can be minted with createItem method.
    uint256 public constant MINT_TOKEN_MAX =
        999999999999999999999999999999999999999999999999999999999999999;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant REDEEMER_ROLE = keccak256("REDEEMER_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    //represent the event emited after redeeming a voucher
    event NFTRedeemed(uint256 tokenId, address minter, address redeemer);

    constructor() initializer {}

    function __ERC721NFT_init(
        string memory name,
        string memory symbol,
        address owner,
        address _marketContract
    ) public initializer {
        __ERC721_init_unchained(name, symbol);
        __ERC721URIStorage_init_unchained();
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
        __ERC721NFT_init_unchained(owner, _marketContract);
    }

    function __ERC721NFT_init_unchained(address owner, address _marketContract)
        internal
        onlyInitializing
    {
        _grantRole(OWNER_ROLE, owner);
        _grantRole(MINTER_ROLE, owner);
        _grantRole(REDEEMER_ROLE, _marketContract);
        _setRoleAdmin(MINTER_ROLE, OWNER_ROLE);
        _setRoleAdmin(REDEEMER_ROLE, OWNER_ROLE);
    }

    /**
    @dev function to create new NFT.
    @param _uri metadata URI of token. 
    @notice caller must be of minter role.
    */
    function createItem(string calldata _uri) public returns (uint256) {
        // check if the caller has the minter role.
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "unauthorized: Only MINTER is allowed to MINT new token"
        );

        // incrimenting counter by 1
        _tokenIds.increment();

        // save current counter value as tokenId
        uint256 tokenId = _tokenIds.current();
        require(
            tokenId <= MINT_TOKEN_MAX,
            "tokenId should be less than MINT_TOKEN_MAX"
        );
        require(_createItem(_uri, tokenId), "create new token failed");
        return tokenId;
    }

    /**
    @dev redeem a new NFT by a redeemer.
    @param minter address to which new token is minted.
    @param tokenId id of the new token. tokenId should be greater than
    @param uri uri string for the new NFT.
    @notice caller must be of redeemer role.
    */
    function redeem(
        address minter,
        uint256 tokenId,
        string memory uri
    ) public returns (bool) {
        require(
            hasRole(REDEEMER_ROLE, _msgSender()),
            "unauthorized: Only REDEEMER is allowed to REDEEM voucher"
        );

        require(
            hasRole(MINTER_ROLE, minter),
            "unauthorized: Only MINTER is allowed to MINT NFT "
        );
        require(
            tokenId > MINT_TOKEN_MAX,
            "tokenId should be greater than MINT_TOKEN_MAX"
        );
        // assign the token to the minter.
        _safeMint(minter, tokenId);
        _setTokenURI(tokenId, uri);

        // approves redeemer to spend the token.
        _setApprovalForAll(minter, _msgSender(), true);

        //emitting redeem event
        emit NFTRedeemed(tokenId, minter, _msgSender());
        return true;
    }

    /**
    @dev function to burn NFT
    @param tokenId NFT id
    * See {ERC721}.
    *
    * Requirements:
    *
    * - the caller must be owner of the token.
    */
    function burn(uint256 tokenId) public virtual returns (bool) {
        require(ownerOf(tokenId) == _msgSender(), "caller is not the owner");
        _burn(tokenId);
        return true;
    }

    /**
    @dev internal function to create new NFT.
    @param _uri metadata URI of token. 
    */
    function _createItem(string memory _uri, uint256 _tokenId)
        internal
        returns (bool)
    {
        // minting token to callers address.
        _safeMint(_msgSender(), _tokenId);

        // setting tokenUri
        _setTokenURI(_tokenId, _uri);

        return true;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlUpgradeable, ERC721Upgradeable)
        returns (bool)
    {
        return
            ERC721Upgradeable.supportsInterface(interfaceId) ||
            AccessControlUpgradeable.supportsInterface(interfaceId);
    }
}
