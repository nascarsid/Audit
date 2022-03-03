// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Vizva721 is
    ERC721Upgradeable,
    PausableUpgradeable,
    OwnableUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIds;

    // emitted when NFT minted in a batch
    event batchNFTMinted(uint256 startIndex, uint256 endIndex);

    /**
     * @dev initialize the Marketplace contract.
     * setting msg sender as owner.
     * @param _name - name of the token. See{ERC721}.
     * @param  _symbol - symbol of the token. See{EIP712}
     *
     * Note:initializer modifier is used to prevent initialize contract twice.
     */
    function __VizvaToken_init(string memory _name, string memory _symbol)
        public
        initializer
    {
        __ERC721_init(_name, _symbol);
        __Ownable_init_unchained();
        __Pausable_init_unchained();
    }

    mapping(uint256 => string) internal uri;

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
    @dev function to create new NFT.
    @param _uri metadata URI of token. 
    */
    function createItem(string memory _uri)
        public
        whenNotPaused
        returns (uint256)
    {
        // incrimenting counter by 1
        _tokenIds.increment();

        // save current counter value as tokenId
        uint256 tokenId = _tokenIds.current();

        require(_createItem(_uri, tokenId), "create new token failed");
        return tokenId;
    }

    /**
    @dev function to create new NFT.
    @param uriArray metadata URI of token. 
    */
    function batchCreateItem(string[] calldata uriArray)
        public
        whenNotPaused
        onlyOwner
        returns (uint256 startIndex, uint256 endIndex)
    {
        // id of the first NFT minted.
        startIndex = _tokenIds.current() + 1;

        // looping over all the uris in uriArray
        for (uint256 i = 0; i < uriArray.length; i++) {

            // incrimenting counter by 1
            _tokenIds.increment();

            // save current counter value as tokenId
            uint256 tokenId = _tokenIds.current();
            string memory _uri = uriArray[i];
            require(_createItem(_uri, tokenId), "create new token failed");
        }

        // id of the last NFT minted.
        endIndex = _tokenIds.current();
        emit batchNFTMinted(startIndex, endIndex);
        return (startIndex, endIndex);
    }

    /**
    @dev internal function to set token URI
    @param tokenId NFT Id.
    @param _uri metadata URI of token.
    */
    function setURI(uint256 tokenId, string memory _uri) internal {
        uri[tokenId] = _uri;
    }

    /**
    @dev function to get token URI.
    @param tokenId NFT Id.
    */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        return uri[tokenId];
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
        setURI(_tokenId, _uri);

        return true;
    }
}
