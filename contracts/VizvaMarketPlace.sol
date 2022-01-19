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
    //represent details of market item
    struct SaleOrder {
        bool isSold;
        bool cancelled;
        uint8 saleType; //1 for instantSale 2 for Auction
        uint256 askingPrice;
        uint256 id;
        address payable creator;
        address payable seller;
        TokenData tokenData;
    }

    struct TokenData {
        uint8 tokenType; //1 for 721 and 2 for 1155
        uint8 royalty;
        uint256 tokenId;
        address tokenAddress;
    }

    //Represents bid data
    struct BidVoucher {
        address tokenAddress;
        uint256 tokenId;
        uint256 marketId;
        uint256 bid;
        bytes signature;
    }

    address internal WALLET;
    address internal WRAPPED_ADDRESS;
    uint256 public ETHComission;

    // string private constant SIGNING_DOMAIN = "VIZVA_MARKETPLACE";
    // string private constant SIGNATURE_VERSION = "1";

    function __VizvaMarket_init(
        address _wallet,
        address _wrappedToken,
        string memory SIGNING_DOMAIN,
        string memory SIGNATURE_VERSION
    ) public initializer {
        __EIP712_init(SIGNING_DOMAIN, SIGNATURE_VERSION);
        __Pausable_init();
        __Ownable_init_unchained();
        __VizvaMarket_init_unchained(_wallet, _wrappedToken);
    }

    function __VizvaMarket_init_unchained(
        address _wallet,
        address _wrappedToken
    ) internal initializer {
        WALLET = _wallet;
        WRAPPED_ADDRESS = _wrappedToken;
    }

    SaleOrder[] public itemsForSale;
    mapping(address => mapping(uint256 => bool)) activeItems;

    event itemAdded(
        uint256 id,
        uint256 tokenId,
        uint256 askingPrice,
        uint256 royalty,
        address tokenAddress,
        address creator
    );
    event itemSold(
        uint256 id,
        address buyer,
        uint256 sellPrice,
        uint256 tranferAmount,
        uint256 royalty
    );

    event saleCancelled(uint256 id);

    modifier OnlyItemOwner(address tokenAddress, uint256 tokenId) {
        IERC721Upgradeable tokenContract = IERC721Upgradeable(tokenAddress);
        require(
            tokenContract.ownerOf(tokenId) == msg.sender,
            "Only Item owner alowed to list in market"
        );
        _;
    }

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

    modifier ItemExists(uint256 id) {
        require(
            id < itemsForSale.length && itemsForSale[id].id == id,
            "Could not find requested item"
        );
        _;
    }

    modifier IsForSale(uint256 id) {
        require(itemsForSale[id].isSold == false, "Item is already sold!");
        _;
    }

    modifier IsCancelled(uint256 id) {
        require(
            itemsForSale[id].cancelled == false,
            "Item sale already cancelled"
        );
        _;
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

    function withdrawETH(uint256 amount) external virtual onlyOwner {
        require(
            address(this).balance <= amount,
            "amount should be less than avalable balance"
        );
        (bool success, ) = WALLET.call{value: amount}("");
        require(success, "Value Transfer Failed.");
    }

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
                msg.value,
                transferValue,
                royaltyValue
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

        IERC20Upgradeable WRAPPED = IERC20Upgradeable(WRAPPED_ADDRESS);
        require(
            WRAPPED.balanceOf(_winner) >= voucher.bid,
            "Not enough WETH in the winner address"
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
        WRAPPED.transferFrom(_winner, _seller, transferValue);
        WRAPPED.transferFrom(
            _winner,
            itemsForSale[voucher.marketId].creator,
            royaltyValue
        );
        WRAPPED.transferFrom(_winner, WALLET, commission);
        emit itemSold(
            voucher.marketId,
            _winner,
            voucher.bid,
            transferValue,
            royaltyValue
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
                            "BidVoucher(address tokenAddress,uint256 tokenId,uint256 marketId,uint256 bid)"
                        ),
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
