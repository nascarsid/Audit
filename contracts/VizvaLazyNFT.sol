//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract VizvaLazyNFT_V1 is
    ERC721URIStorageUpgradeable,
    AccessControlUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{

    bytes32 public constant REDEEMER_ROLE = keccak256("REDEEMER_ROLE");

    //represent the event emited after redeeming a voucher
    event NFTRedeemed(
        uint256 tokenId,
        address minter,
        address redeemer
    );

    constructor() initializer {}

    function __VizvaLazyNFT_V1_init(
        string memory name,
        string memory symbol,
        address redeemer
    ) public initializer {
        __ERC721_init_unchained(name, symbol);
        __ERC721URIStorage_init_unchained();
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
        __Ownable_init_unchained();
        __Pausable_init_unchained();
        __VizvaLazyNFT_V1_init_unchained(redeemer);
    }

    function __VizvaLazyNFT_V1_init_unchained(address redeemer) internal onlyInitializing {
        _grantRole(REDEEMER_ROLE, redeemer);
    }

    /// @notice redeem a new NFT by a redeemer.
    /// @param minter address to which new token is minted.
    /// @param tokenId id of the new token.
    /// @param uri uri string for the new NFT.
    function redeem(
        address minter,
        uint256 tokenId,
        string memory uri
    ) public returns (bool){

        // check the caller has the redeemer role.
        require(hasRole(REDEEMER_ROLE, _msgSender()), "unauthorized: Only REDEEMER is allowed to redeem token");
        
        // assign the token to the minter.
        _safeMint(minter, tokenId);
        _setTokenURI(tokenId, uri);

        // approves redeemer to spend the token.
        _setApprovalForAll(minter, _msgSender(), true);

        //emitting redeem event
        emit NFTRedeemed(
            tokenId,
            minter,
            _msgSender()
        );
        return true;
    }

    /**
     * @dev Pauses the market contract.
     *
     * See {ERC20Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must be the owner of the contract.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the market contract.
     *
     * See {ERC20Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must be owner of the contract.
     */
    function unpause() public onlyOwner {
        _unpause();
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
