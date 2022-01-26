// SPDX-License-Identifier: MIT

pragma solidity 0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract VizvaMarket_V1 is
    ERC721URIStorageUpgradeable,
    EIP712Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    /**
    @dev Struct represent the details of an market order
    Note: 
        uint8 saleType; //Used as an Identifier; 1 for instantSale 2 for Auction
        TokenData tokenData; //Struct contains the details of an NFT.
     */
    struct SaleOrder {
        bool isSold; // shows whether the sale is completed or not.
        bool cancelled; // shows whether the sale is cancelled or not.
        uint8 saleType; //Used as an Identifier; 1 for instantSale 2 for Auction.
        uint256 askingPrice; // the minimum price set by the seller for an NFT.
        uint256 id; //unique id of the sale
        address seller; //address of the seller.
        TokenData tokenData; //struct contains the details of an NFT.
    }

    /**
    @dev Struct represent the details of an NFT.
    Note:
        uint256 amount => Included for the support of ERC1155. Value Should be 1 for ERC721 Token.
     */
    struct TokenData {
        uint8 tokenType; // Used as an Identifier; value = 1 for ERC721 Token & 2 for ERC1155 Token.
        uint16 royalty; // percentage of share for creator.
        uint256 tokenId; //id of NFT
        uint256 amount; //amount of NFT on sale.
        address tokenAddress; // NFT smartcontract address.
        address creator; // address of the creator of the NFT.
    }

    /**
    @dev Struct represents the details of Bidvoucher.
     */
    struct BidVoucher {
        address asset; //address of the token used to exchange NFT.
        address tokenAddress; //NFT smartcontract address.
        uint256 tokenId; //id of the token
        uint256 marketId; //Id of the sale for wich bid placed.
        uint256 bid; //the bidded amount.
        bytes signature; //EIP-712 signature by the bidder.
    }

    /** 
    @dev Represents an un-minted NFT, which has not yet been recorded into the blockchain.
        A signed voucher can be redeemed for a real NFT using the redeem function.
    */
    struct NFTVoucher {
        uint256 tokenId;
        uint256 minPrice;
        uint16 royalty;
        string uri;
        bytes signature;
    }

    // address to which withdraw function transfers funds.
    address internal WALLET;

    // Represent the percentage of share, contract recieve as commission on
    // every NFT sale. Value should be entered as multiplied with 10 to avoid
    // precision error. Commission 2.5% should be added as 25.
    uint16 public commission;

    SaleOrder[] public itemsForSale; // contains array of all Items put on sale.
    mapping(address => mapping(uint256 => bool)) activeItems; // contains all active Items

    /**
     * @dev Emitted when new Item added using _addItemToMarket function
     */
    event itemAdded(
        uint256 id,
        uint256 tokenId,
        uint256 askingPrice,
        uint16 royalty,
        address tokenAddress,
        address creator
    );
    /**
     * @dev Emitted when an Item is sold,` price` contains 3 different values
     * total value, the value received by the seller, value received by creator
     */
    event itemSold(uint256 id, address buyer, uint256[3] price, address asset);

    /**
    @dev represent the event emited after redeeming a voucher
     */
    event NFTRedeemed(
        uint256 minPrice,
        uint256 tokenId,
        address tokenAddress,
        address creator,
        address buyer
    );

    /**
     * @dev Emitted when an Item Sale cancelled.
     */
    event saleCancelled(uint256 id);

    // prevent intialization of logic contract.
    constructor() initializer {}

    /**
     * @dev initialize the Marketplace contract.
     * setting msg sender as owner.
     * @param
     *  _wallet - address to withdraw MATIC.
     * SIGNING_DOMAIN {EIP712}
     * SIGNATURE_VERSION {EIP712}
     * Note:initializer modifier is used to prevent initialization of contract twice.
     */
    function __VizvaMarket_init(
        uint16 _commission,
        address _wallet,
        string memory _tokenName,
        string memory _tokenSymbol,
        string memory SIGNING_DOMAIN,
        string memory SIGNATURE_VERSION
    ) public virtual initializer {
        __ERC721_init(_tokenName, _tokenSymbol);
        __EIP712_init_unchained(SIGNING_DOMAIN, SIGNATURE_VERSION);
        __Pausable_init_unchained();
        __Ownable_init_unchained();
        __VizvaMarket_init_unchained(_wallet, _commission);
    }

    function __VizvaMarket_init_unchained(address _wallet, uint16 _commission)
        internal
        onlyInitializing
    {
        WALLET = _wallet;
        commission = _commission;
    }

    /**
    @dev Modifier to restrict function access only to NFT Owner.
     */
    modifier OnlyItemOwner(address tokenAddress, uint256 tokenId) {
        IERC721Upgradeable tokenContract = IERC721Upgradeable(tokenAddress);
        require(
            tokenContract.ownerOf(tokenId) == _msgSender(),
            "Only Item owner alowed to list in market"
        );
        _;
    }

    /**
    @dev Modifier to check whether this contract has transfer approval.
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
    @dev Modifier to check whether Item sales exist.
     */
    modifier ItemExists(uint256 id) {
        require(
            id < itemsForSale.length && itemsForSale[id].id == id,
            "Could not find requested item"
        );
        _;
    }

    /**
    @dev Modifier to check whether `id` exists for sale.
     */
    modifier IsForSale(uint256 id) {
        require(itemsForSale[id].isSold == false, "Item is already sold!");
        _;
    }

    /**
    @dev Modifier to check whether `id` sale cancelled or not.
     */
    modifier IsCancelled(uint256 id) {
        //checking if already cancelled
        require(
            itemsForSale[id].cancelled == false,
            "Item sale already cancelled"
        );
        _;
    }

    /**
    @dev external function to withdraw MATIC received as commission.
    @param amount - this much token will be transferred to WALLET.
     */
    function withdraw(uint256 amount) external virtual onlyOwner nonReentrant {
        // checking if amount is less than available balance.
        require(
            address(this).balance <= amount,
            "amount should be less than avalable balance"
        );

        //transferring amount.
        (bool success, ) = WALLET.call{value: amount}("");
        require(success, "Value Transfer Failed.");
    }

    // public function to get all items for sale
    function getAllItemForSale() public view returns (SaleOrder[] memory saleOrder){
        return itemsForSale;
    }

    /**
    @dev function to update the commission of the Marketplace.
    @param _newValue - new value for the commission. 
    Note value should be multiplied by 10. If commission is 2.5%
        it should be entered as 25. 
    Requirement:- caller should be the owner.
    */
    function updateCommission(uint16 _newValue) public virtual onlyOwner {
        require(_newValue < 500, "commission can't be greater than 50%.");
        commission = _newValue;
    }

    /**
    @dev Function to add new Item to market.
    @param saleType - used as an Identifier. saleType = 1 for instant sale and saleType = 2 for auction
    @param askingPrice - minimum price required to buy Item.
    @param tokenData - contains details of NFT. refer struct TokenData
     */
    function addItemToMarket(
        uint8 saleType,
        uint256 askingPrice,
        TokenData calldata tokenData
    )
        public
        virtual
        OnlyItemOwner(tokenData.tokenAddress, tokenData.tokenId)
        HasNFTTransferApproval(
            tokenData.tokenAddress,
            tokenData.tokenId,
            _msgSender()
        )
        whenNotPaused
        returns (uint256)
    {
        //checking if the NFT already on Sale.
        require(
            activeItems[tokenData.tokenAddress][tokenData.tokenId] == false,
            "Item is already up for sale!"
        );

        //getting new Id for the Item.
        uint256 newItemId = itemsForSale.length;
        address seller = _msgSender();
        //internal function to add new Item on Market.
        _addItemToMarket(saleType, askingPrice, newItemId, seller, tokenData);

        //return marketId of the Item.
        return newItemId;
    }

    /**
    @dev Function to add new Item to market.
    @param _tokenAddress - address of the buying NFT. (For cross-checking)
    @param _tokenId - id of the buying NFT. (For cross-checking)
    @param _id - id of the sale.
    Note -
        if commission is 25, it means 25/(100*10), ie; 2.5% 
        commission% of the askingPrice will be reduced as commission.
        royalty% of the askingPrice will be transferred to NFT creator.
        The seller will receive a (100 - royalty)% share of the askingPrice.
        Commission values are multiplied by 10 to avoid a precision issues. 
     */
    function buyItem(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _id
    )
        public
        payable
        virtual
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
        //getting seller address from sale data.
        address seller = itemsForSale[_id].seller;

        /**
        @dev scope added to resolve stack too deep error
        */
        {
            //getting token address from sale data.
            address tokenAddress = itemsForSale[_id].tokenData.tokenAddress;

            //getting tokenId from sale data.
            uint256 tokenId = itemsForSale[_id].tokenData.tokenId;

            // checking if the value includes commission.
            require(
                msg.value >=
                    ((itemsForSale[_id].askingPrice) * (1000 + commission)) /
                        1000,
                "Not enough funds sent, Please include commission"
            );

            // checking if item is on instant sale.
            require(
                itemsForSale[_id].saleType == 1,
                "can't purachase token on auction"
            );

            // seller not allowed to purchase Item.
            require(
                _msgSender() != seller,
                "seller can't purchase created Item"
            );

            // checking if the requested tokenId is same as the sale tokenId.
            require(tokenId == _tokenId, "unexpected tokenId");

            // checking if the requested tokenAddress is the same as the sale tokenAddress.
            require(tokenAddress == _tokenAddress, "unexpected token Address");

            // marking item as sold.
            itemsForSale[_id].isSold = true;

            // removing item from active item list.
            activeItems[tokenAddress][tokenId] = false;

            //transferring token buyer.
            IERC721Upgradeable(tokenAddress).safeTransferFrom(
                seller,
                _msgSender(),
                tokenId
            );
        }
        {
            // getting royality value.
            uint16 royalty = itemsForSale[_id].tokenData.royalty;

            // calculating value receivable by creator. Decimals are not allowed as royalty.
            uint256 royaltyValue = (itemsForSale[_id].askingPrice * royalty) /
                100;

            // calculating commission.
            uint256 commissionValue = (itemsForSale[_id].askingPrice *
                commission) / 1000;

            // calculating value receivable by seller.
            uint256 transferValue = msg.value - royaltyValue - commissionValue;

            //transferring share of seller.
            (bool valueSuccess, ) = seller.call{value: transferValue}("");
            require(valueSuccess, "Value Transfer Failed.");

            //transferring share of the creator. rest of msg.value(buy price) will be
            // stored in the contract as commission.
            (bool royaltySuccess, ) = itemsForSale[_id].tokenData.creator.call{
                value: royaltyValue
            }("");
            require(royaltySuccess, "royalty transfer failed");

            //emmitting item sold event.
            emit itemSold(
                _id,
                _msgSender(),
                [msg.value, transferValue, royaltyValue],
                address(0)
            );
        }
    }

    /**
    @dev function to transfer NFT to auction winner.
    @param voucher - contains bidding details. EIP712 type.
    @param _winner - auction winner address. NFT will be transferred to this address.
    Note -
        commission% of the askingPrice will be transferred as commission to WALLET.
        royalty% of the askingPrice will be transferred to NFT creator.
        The seller will receive a (100 - royalty)% of the msg.value.
        Commission values are multiplied by 10 to avoid a precision issues.  
     */
    function finalizeBid(BidVoucher calldata voucher, address _winner)
        public
        virtual
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
        //retrieving signer address from EIP-712 voucher.
        address signer = _verifyBid(voucher);

        //getting seller address from sale data.
        address seller = itemsForSale[voucher.marketId].seller;

        //getting tokenId from sale data.
        uint256 tokenId = itemsForSale[voucher.marketId].tokenData.tokenId;

        //checking if the Item is on Auction
        require(
            itemsForSale[voucher.marketId].saleType == 2,
            "can't bid token on instant sale"
        );

        // make sure signature is valid and get the address of the signer
        require(signer == _winner, "Signature invalid or unauthorized");

        // checking if the value includes commission.
        require(
            voucher.bid >=
                ((itemsForSale[voucher.marketId].askingPrice) *
                    (1000 + commission)) /
                    1000,
            "bid amount is lesser than required price"
        );

        // checking if auction winner is the seller.
        require(_winner != seller, "seller can't purchase created Item");

        // checking if the requested tokenId is same as the sale tokenId.
        require(tokenId == voucher.tokenId, "unexpected tokenId");

        // internal function for finalizing the bid.
        _finalizeBid(voucher, _winner, seller);
    }

    /**
    @dev Function to cancel an item from sale. Cancelled Items can't be purchased.
    @param _id - id the Sale Item. 
     */
    function cancelSale(uint256 _id)
        public
        virtual
        ItemExists(_id)
        IsCancelled(_id)
    {
        address tokenAddress = itemsForSale[_id].tokenData.tokenAddress;
        uint256 tokenId = itemsForSale[_id].tokenData.tokenId;
        itemsForSale[_id].cancelled = true;
        activeItems[tokenAddress][tokenId] = false;
        emit saleCancelled(_id);
    }

    /// @notice Redeems an NFTVoucher for an actual NFT, creating it in the process.
    /// @param voucher A signed NFTVoucher that describes the NFT to be redeemed.
    function redeem(NFTVoucher calldata voucher, address creator)
        public
        payable
        returns (uint256)
    {
        // make sure signature is valid and get the address of the signer
        address signer = _verifyNFTVoucher(voucher);

        // make sure that the signer is authorized to mint NFTs
        require(signer == creator, "Signature invalid or unauthorized");

        // make sure that the redeemer is paying enough to cover the buyer's cost
        // the total price should be greater than the sum of minimum price
        // and commission
        require(
            msg.value >= (voucher.minPrice * (1000 + commission)) / 1000,
            "Insufficient funds to redeem"
        );

        // first assign the token to the signer, to establish provenance on-chain
        _safeMint(signer, voucher.tokenId);

        // setting token uri
        _setTokenURI(voucher.tokenId, voucher.uri);

        //getting approval for transfering NFT
        _setApprovalForAll(signer, address(this), true);

        // creating token data.
        TokenData memory _tokenData = TokenData(
            1,
            voucher.royalty,
            voucher.tokenId,
            1,
            address(this),
            signer
        );

        // getting new market Id
        uint256 newItemId = itemsForSale.length;

        //adding item to market, to establish provenance on-chain.
        _addItemToMarket(1, voucher.minPrice, newItemId, signer, _tokenData);

        // transfer the token to the redeemer
        buyItem(address(this), voucher.tokenId, newItemId);

        //emitting redeem event
        emit NFTRedeemed(
            voucher.minPrice,
            voucher.tokenId,
            address(this),
            signer,
            _msgSender()
        );

        //returning tokenId
        return voucher.tokenId;
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
    function pause() public virtual onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the market contract.
     *
     * See {ERC20Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must be the owner of the contract.
     */
    function unpause() public virtual onlyOwner {
        _unpause();
    }

    /**
    @dev internal function for adding new item to market
    * See {addItemToMarket}
    */
    function _addItemToMarket(
        uint8 _saleType,
        uint256 _askingPrice,
        uint256 _newItemId,
        address _seller,
        TokenData memory _tokenData
    ) internal virtual {
        // adding data to itemsForSale struct.
        itemsForSale.push(
            SaleOrder(
                false,
                false,
                _saleType,
                _askingPrice,
                _newItemId,
                payable(_seller),
                _tokenData
            )
        );

        // adding Item to active list.
        activeItems[_tokenData.tokenAddress][_tokenData.tokenId] = true;

        // checking if requested tokenId is same as that in the Sale Data
        require(itemsForSale[_newItemId].id == _newItemId, "Item id mismatch");

        // emit item added event.
        emit itemAdded(
            _newItemId,
            _tokenData.tokenId,
            _askingPrice,
            _tokenData.royalty,
            _tokenData.tokenAddress,
            _tokenData.creator
        );
    }

    /**
    @dev internal function to transfer NFT to auction winner.
    * See {finalizeBid}
    */
    function _finalizeBid(
        BidVoucher calldata voucher,
        address _winner,
        address _seller
    ) internal virtual {
        // getting tokenAddress from sale data.
        address tokenAddress = itemsForSale[voucher.marketId]
            .tokenData
            .tokenAddress;

        // getting royalty from sale data.
        uint16 royalty = itemsForSale[voucher.marketId].tokenData.royalty;

        // getting tokenId from sale data.
        uint256 tokenId = itemsForSale[voucher.marketId].tokenData.tokenId;

        // initializing token instance.
        IERC20Upgradeable ERC20 = IERC20Upgradeable(voucher.asset);

        // checking the balance of ERC20 token is greater than bid.
        require(
            ERC20.balanceOf(_winner) >= voucher.bid,
            "Not enough Token Balance in the winner address"
        );

        // checking if the requested token address is same as the voucher token address.
        require(
            tokenAddress == voucher.tokenAddress,
            "unexpected token Address"
        );

        // marking the Item as sold.
        itemsForSale[voucher.marketId].isSold = true;

        // removing Item from active list.
        activeItems[tokenAddress][tokenId] = false;

        // transferring NFT.
        IERC721Upgradeable(tokenAddress).safeTransferFrom(
            _seller,
            _winner,
            tokenId
        );

        uint256 commissionValue = (itemsForSale[voucher.marketId].askingPrice *
            commission) / 1000;

        // calculating royalty value receivable by creator.
        uint256 royaltyValue = (itemsForSale[voucher.marketId].askingPrice *
            royalty) / 100;

        // calculating value receivable by seller.
        uint256 transferValue = voucher.bid - commissionValue - royaltyValue;

        // transferring seller share.
        ERC20.transferFrom(_winner, _seller, transferValue);

        // transferring royalty value.
        ERC20.transferFrom(
            _winner,
            itemsForSale[voucher.marketId].tokenData.creator,
            royaltyValue
        );

        // transferring commission to the wallet.
        ERC20.transferFrom(_winner, WALLET, commissionValue);

        // emiting item sold event.
        emit itemSold(
            voucher.marketId,
            _winner,
            [voucher.bid, transferValue, royaltyValue],
            voucher.asset
        );
    }

    /**
    @dev internal function to recover and signed data
    @param voucher EIP712 signed voucher
     */
    function _verifyBid(BidVoucher calldata voucher)
        internal
        view
        virtual
        returns (address)
    {
        bytes32 digest = _hash(
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
        );
        return ECDSAUpgradeable.recover(digest, voucher.signature);
    }

    /// @notice Verifies the signature for a given NFTVoucher, returning the address of the signer.
    /// @dev Will revert if the signature is invalid. Does not verify that the signer is authorized to mint NFTs.
    /// @param voucher An NFTVoucher describing an unminted NFT.
    function _verifyNFTVoucher(NFTVoucher calldata voucher)
        internal
        view
        returns (address)
    {
        bytes32 digest = _hash(
            abi.encode(
                keccak256(
                    "NFTVoucher(uint256 tokenId,uint256 minPrice,uint16 royalty,string uri)"
                ),
                voucher.tokenId,
                voucher.minPrice,
                voucher.royalty,
                keccak256(bytes(voucher.uri))
            )
        );
        return ECDSAUpgradeable.recover(digest, voucher.signature);
    }

    /// @notice Returns a hash of the given ABI encoded voucher, prepared using EIP712 typed data hashing rules.
    /// @param voucher An encoded voucher to hash.
    function _hash(bytes memory voucher)
        internal
        view
        virtual
        returns (bytes32)
    {
        return _hashTypedDataV4(keccak256(voucher));
    }

    /// @notice Returns the chain id of the current blockchain.
    /// @dev This is used to workaround an issue with ganache returning different values from the on-chain chainid() function and
    ///  the eth_chainId RPC method. See https://github.com/protocol/nft-website/issues/121 for context.
    function getChainID() external view virtual returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }
}
