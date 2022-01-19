// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract VizvaMarket_V1 is
    EIP712Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    /**
    @dev Struct represent the details of an market order
    Note: 
        uint8 saleType; //Used as an Identifier; 1 for instantSale 2 for Auction
        TokenData tokenData; //Struct contains the details of a NFT.
     */
    struct SaleOrder {
        bool isSold;
        bool cancelled;
        uint8 saleType; //Used as an Identifier; 1 for instantSale 2 for Auction.
        uint256 askingPrice;
        uint256 id;
        address payable creator;
        address payable seller;
        TokenData tokenData; //contains details of a NFT.
    }

    /**
    @dev Struct represent the details of a NFT.
    Note:
        uint8 tokenType; // Used as an Identifier; value = 1 for ERC721 Token & 2 for ERC1155 Token.
        uint8 royalty; // percentage of share for creator.
        uint256 amount; // Should be 1 for ERC721 Token.
     */
    struct TokenData {
        uint8 tokenType;
        uint8 royalty;
        uint256 tokenId;
        uint256 amount;
        address tokenAddress;
    }

    /**
    @dev Struct represent the details of Bidvoucher.
    Note: 
        address asset; // address of the exchange token
        address tokenAddress; // address of the NFT contract
     */
    struct BidVoucher {
        address asset;
        address tokenAddress;
        uint256 tokenId;
        uint256 marketId;
        uint256 bid;
        bytes signature;
    }

    address internal WALLET;
    uint256 public ETHComission;

    /**
     * @dev initialize the Marketplace contract.
     * setting msg sender as owner.
     * @param
     *  _wallet - address to withdraw MATIC.
     * SIGNING_DOMAIN {EIP712}
     * SIGNATURE_VERSION {EIP712}
     * Note:initializer modifier is used to prevent initialize contract twice.
     */
    function __VizvaMarket_init(
        address _wallet,
        string memory SIGNING_DOMAIN,
        string memory SIGNATURE_VERSION
    ) public initializer {
        __EIP712_init(SIGNING_DOMAIN, SIGNATURE_VERSION);
        __Pausable_init();
        __Ownable_init_unchained();
        __VizvaMarket_init_unchained(_wallet);
    }

    function __VizvaMarket_init_unchained(address _wallet)
        internal
        initializer
    {
        WALLET = _wallet;
    }

    SaleOrder[] public itemsForSale;
    mapping(address => mapping(uint256 => bool)) activeItems;

    /**
     * @dev Emitted when new Item added using _addItemToMarket function
     */
    event itemAdded(
        uint256 id,
        uint256 tokenId,
        uint256 askingPrice,
        uint256 royalty,
        address tokenAddress,
        address creator
    );
    /**
     * @dev Emitted when an Item is sold,`price` contains 3 different values
     * total value, value recieved by seller, value recieved by creator
     */
    event itemSold(uint256 id, address buyer, uint256[3] price, address asset);

    /**
     * @dev Emitted when an Item Sale cancelled.
     */
    event saleCancelled(uint256 id);

    /**
    @dev Modifier to restrict function access only to NFT Owner.
     */
    modifier OnlyItemOwner(address tokenAddress, uint256 tokenId) {
        IERC721Upgradeable tokenContract = IERC721Upgradeable(tokenAddress);
        require(
            tokenContract.ownerOf(tokenId) == msg.sender,
            "Only Item owner alowed to list in market"
        );
        _;
    }

    /**
    @dev Modifier to check whether the this contract has transfer approval.
     */
    modifier HasNFTTransferApproval(
        address tokenAddress,
        uint256 tokenId,
        address sender
    ) {
        IERC721Upgradeable tokenContract = IERC721Upgradeable(tokenAddress);
        require(
            tokenContract.getApproved(tokenId) == address(this) ||
                tokenContract.isApprovedForAll(sender, address(this)),
            "token transfer not approved"
        );
        _;
    }

    /**
    @dev Modifier to check whether Item sale exist.
     */
    modifier ItemExists(uint256 id) {
        require(
            id < itemsForSale.length && itemsForSale[id].id == id,
            "Could not find requested item"
        );
        _;
    }

    /**
    @dev Modifier to check whether `id` exist for sale.
     */
    modifier IsForSale(uint256 id) {
        require(itemsForSale[id].isSold == false, "Item is already sold!");
        _;
    }

    /**
    @dev Modifier to check whether `id` sale cancelled or not .
     */
    modifier IsCancelled(uint256 id) {
        require(
            itemsForSale[id].cancelled == false,
            "Item sale already cancelled"
        );
        _;
    }

    /**
    @dev external function to withdraw MATIC recieved as commission.
    @param amount - this much token will be transfered to WALLET.
     */
    function withdraw(uint256 amount) external virtual onlyOwner {
        require(
            address(this).balance <= amount,
            "amount should be less than avalable balance"
        );
        (bool success, ) = WALLET.call{value: amount}("");
        require(success, "Value Transfer Failed.");
    }

    /**
    @dev Function to add new Item to market.
    @param saleType - used as an Identifier. saleType = 1 for instant sale and saleType = 2 for auction
    @param askingPrice - minimum price required to buy Item.
    @param creator - address of the creator of the NFT.
    @param tokenData - contains details of NFT. refer TokenData
     */
    function addItemToMarket(
        uint8 saleType,
        uint256 askingPrice,
        address creator,
        TokenData calldata tokenData
    )
        public
        OnlyItemOwner(tokenData.tokenAddress, tokenData.tokenId)
        HasNFTTransferApproval(
            tokenData.tokenAddress,
            tokenData.tokenId,
            msg.sender
        )
        whenNotPaused
        returns (uint256)
    {
        require(
            activeItems[tokenData.tokenAddress][tokenData.tokenId] == false,
            "Item is already up for sale!"
        );
        uint256 newItemId = itemsForSale.length;
        _addItemToMarket(saleType, askingPrice, newItemId, creator, tokenData);
        return newItemId;
    }

    function buyItem(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _id
    )
        public
        payable
        whenNotPaused
        ItemExists(_id)
        IsForSale(_id)
        IsCancelled(_id)
        HasNFTTransferApproval(
            itemsForSale[_id].tokenData.tokenAddress,
            itemsForSale[_id].tokenData.tokenId,
            itemsForSale[_id].seller
        )
        nonReentrant
    {
        address seller = itemsForSale[_id].seller;
        {
            address tokenAddress = itemsForSale[_id].tokenData.tokenAddress;
            uint256 tokenId = itemsForSale[_id].tokenData.tokenId;

            require(
                msg.value >= itemsForSale[_id].askingPrice,
                "Not enough funds sent"
            );

            require(
                itemsForSale[_id].saleType == 1,
                "can't purachase token on auction"
            );

            require(msg.sender != seller, "seller can't purchase created Item");

            require(tokenId == _tokenId, "unexpected tokenId");

            require(tokenAddress == _tokenAddress, "unexpected token Address");

            itemsForSale[_id].isSold = true;
            activeItems[tokenAddress][tokenId] = false;
            IERC721Upgradeable(tokenAddress).safeTransferFrom(
                seller,
                msg.sender,
                tokenId
            );
        }
        {
            uint256 royalty = itemsForSale[_id].tokenData.royalty;

            uint256 sellerPercentage = 975 - (royalty * 10);
            uint256 transferValue = (msg.value * sellerPercentage) / 1000;
            uint256 royaltyValue = (msg.value * royalty) / 100;
            (bool valueSuccess, ) = seller.call{value: transferValue}("");
            require(valueSuccess, "Value Transfer Failed.");
            (bool royaltySuccess, ) = itemsForSale[_id].creator.call{
                value: royaltyValue
            }("");
            require(royaltySuccess, "royalty transfer failed");
            emit itemSold(
                _id,
                msg.sender,
                [msg.value, transferValue, royaltyValue],
                address(0)
            );
        }
    }

    function finalizeBid(BidVoucher calldata voucher, address _winner)
        public
        whenNotPaused
        ItemExists(voucher.marketId)
        IsForSale(voucher.marketId)
        IsCancelled(voucher.marketId)
        HasNFTTransferApproval(
            itemsForSale[voucher.marketId].tokenData.tokenAddress,
            itemsForSale[voucher.marketId].tokenData.tokenId,
            itemsForSale[voucher.marketId].seller
        )
        nonReentrant
    {
        address signer = _verify(voucher);
        address seller = itemsForSale[voucher.marketId].seller;
        uint256 tokenId = itemsForSale[voucher.marketId].tokenData.tokenId;

        // make sure that the signature is valid
        require(
            itemsForSale[voucher.marketId].saleType == 2,
            "can't bid token on instant sale"
        );
        require(signer == _winner, "Signature invalid or unauthorized");

        require(
            voucher.bid >= itemsForSale[voucher.marketId].askingPrice,
            "bid amount is lesser than min. price"
        );
        require(_winner != seller, "seller can't purchase created Item");

        require(tokenId == voucher.tokenId, "unexpected tokenId");

        require(!itemsForSale[voucher.marketId].isSold, "Item already sold");

        require(
            !itemsForSale[voucher.marketId].cancelled,
            "Item sale cancelled"
        );
        _finalizeBid(voucher, _winner, seller);
    }

    function cancelSale(uint256 _id) public ItemExists(_id) IsCancelled(_id) {
        address tokenAddress = itemsForSale[_id].tokenData.tokenAddress;
        uint256 tokenId = itemsForSale[_id].tokenData.tokenId;
        itemsForSale[_id].cancelled = true;
        activeItems[tokenAddress][tokenId] = false;
        emit saleCancelled(_id);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _addItemToMarket(
        uint8 _saleType,
        uint256 _askingPrice,
        uint256 _newItemId,
        address _creator,
        TokenData memory _tokenData
    ) internal virtual {
        itemsForSale.push(
            SaleOrder(
                false,
                false,
                _saleType,
                _askingPrice,
                _newItemId,
                payable(_creator),
                payable(msg.sender),
                _tokenData
            )
        );
        activeItems[_tokenData.tokenAddress][_tokenData.tokenId] = true;
        require(itemsForSale[_newItemId].id == _newItemId, "Item id mismatch");
        emit itemAdded(
            _newItemId,
            _tokenData.tokenId,
            _askingPrice,
            _tokenData.royalty,
            _tokenData.tokenAddress,
            _creator
        );
    }

    function _finalizeBid(
        BidVoucher calldata voucher,
        address _winner,
        address _seller
    ) internal {
        address tokenAddress = itemsForSale[voucher.marketId]
            .tokenData
            .tokenAddress;
        uint256 royalty = itemsForSale[voucher.marketId].tokenData.royalty;
        uint256 tokenId = itemsForSale[voucher.marketId].tokenData.tokenId;

        IERC20Upgradeable ERC20 = IERC20Upgradeable(voucher.asset);
        require(
            ERC20.balanceOf(_winner) >= voucher.bid,
            "Not enough Token Balance in the winner address"
        );
        require(
            tokenAddress == voucher.tokenAddress,
            "unexpected token Address"
        );
        itemsForSale[voucher.marketId].isSold = true;
        activeItems[tokenAddress][tokenId] = false;
        IERC721Upgradeable(tokenAddress).safeTransferFrom(
            _seller,
            _winner,
            tokenId
        );
        uint256 sellerPercentage = 975 - (royalty * 10);
        uint256 transferValue = (voucher.bid * sellerPercentage) / 1000;
        uint256 royaltyValue = (voucher.bid * royalty) / 100;
        uint256 commission = (voucher.bid * 25) / 1000;
        ERC20.transferFrom(_winner, _seller, transferValue);
        ERC20.transferFrom(
            _winner,
            itemsForSale[voucher.marketId].creator,
            royaltyValue
        );
        ERC20.transferFrom(_winner, WALLET, commission);
        emit itemSold(
            voucher.marketId,
            _winner,
            [voucher.bid, transferValue, royaltyValue],
            voucher.asset
        );
    }

    function _verify(BidVoucher calldata voucher)
        internal
        view
        returns (address)
    {
        bytes32 digest = _hash(voucher);
        return ECDSAUpgradeable.recover(digest, voucher.signature);
    }

    /// @notice Returns a hash of the given BIDVoucher, prepared using EIP712 typed data hashing rules.
    /// @param voucher An BIDVoucher to hash.
    function _hash(BidVoucher calldata voucher)
        internal
        view
        returns (bytes32)
    {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "BidVoucher(address asset,address tokenAddress,uint256 tokenId,uint256 marketId,uint256 bid)"
                        ),
                        voucher.asset,
                        voucher.tokenAddress,
                        voucher.tokenId,
                        voucher.marketId,
                        voucher.bid
                    )
                )
            );
    }

    /// @notice Returns the chain id of the current blockchain.
    /// @dev This is used to workaround an issue with ganache returning different values from the on-chain chainid() function and
    ///  the eth_chainId RPC method. See https://github.com/protocol/nft-website/issues/121 for context.
    function getChainID() external view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }
}
