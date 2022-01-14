// SPDX-License-Identifier: MIT

/**
 *@dev Contract created for development pupose only.
 * keep on updating as per the requirements.
 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VizvaMarketContract is EIP712, Ownable, ReentrancyGuard {
    //represent details of market item
    struct SaleOrder {
        bool isSold;
        bool cancelled;
        address payable seller;
        address tokenAddress;
        uint256 tokenId;
        uint256 askingPrice;
        uint256 id;
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

    constructor(
        address _wallet,
        address _wrappedToken,
        string memory SIGNING_DOMAIN,
        string memory SIGNATURE_VERSION
    ) EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {
        WALLET = _wallet;
        WRAPPED_ADDRESS = _wrappedToken;
    }

    SaleOrder[] public itemsForSale;
    mapping(address => mapping(uint256 => bool)) activeItems;

    event itemAdded(
        uint256 id,
        uint256 tokenId,
        address tokenAddress,
        uint256 askingPrice
    );
    event itemSold(
        uint256 id,
        address buyer,
        uint256 sellPrice,
        uint256 tranferAmount
    );

    event saleCancelled(uint256 id);

    modifier OnlyItemOwner(address tokenAddress, uint256 tokenId) {
        IERC721 tokenContract = IERC721(tokenAddress);
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
        IERC721 tokenContract = IERC721(tokenAddress);
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

    function withdrawETH(uint256 amount) external virtual onlyOwner {
        require(
            address(this).balance <= amount,
            "amount should be less than avalable balance"
        );
        (bool success, ) = WALLET.call{value: amount}("");
        require(success, "Value Transfer Failed.");
    }

    function withdrawERC20(uint256 amount) external virtual onlyOwner {
        IERC20 WRAPPED = IERC20(WRAPPED_ADDRESS);
        require(
            WRAPPED.balanceOf(address(this)) >= amount,
            "Not enough WETH in the winner address"
        );
        bool success = WRAPPED.transfer(WALLET, amount);
        require(success, "ERC20 Transfer Failed.");
    }

    function addItemToMarket(
        address tokenAddress,
        uint256 tokenId,
        uint256 askingPrice
    )
        external
        OnlyItemOwner(tokenAddress, tokenId)
        HasNFTTransferApproval(tokenAddress, tokenId, msg.sender)
        returns (uint256)
    {
        require(
            activeItems[tokenAddress][tokenId] == false,
            "Item is already up for sale!"
        );
        uint256 newItemId = itemsForSale.length;
        itemsForSale.push(
            SaleOrder(
                false,
                false,
                payable(msg.sender),
                tokenAddress,
                tokenId,
                askingPrice,
                newItemId
            )
        );
        activeItems[tokenAddress][tokenId] = true;

        require(itemsForSale[newItemId].id == newItemId, "Item id mismatch");
        emit itemAdded(newItemId, tokenId, tokenAddress, askingPrice);
        return newItemId;
    }

    function buyItem(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _id
    )
        external
        payable
        ItemExists(_id)
        IsForSale(_id)
        IsCancelled(_id)
        HasNFTTransferApproval(
            itemsForSale[_id].tokenAddress,
            itemsForSale[_id].tokenId,
            itemsForSale[_id].seller
        )
        nonReentrant
    {
        address tokenAddress = itemsForSale[_id].tokenAddress;
        address seller = itemsForSale[_id].seller;
        uint256 tokenId = itemsForSale[_id].tokenId;

        require(
            msg.value >= itemsForSale[_id].askingPrice,
            "Not enough funds sent"
        );

        require(msg.sender != seller, "seller can't purchase created Item");

        require(tokenId == _tokenId, "unexpected tokenId");

        require(tokenAddress == _tokenAddress, "unexpected token Address");

        itemsForSale[_id].isSold = true;
        activeItems[tokenAddress][tokenId] = false;
        IERC721(tokenAddress).safeTransferFrom(seller, msg.sender, tokenId);
        uint256 transferValue = (msg.value * 975) / 1000;
        (bool valueSuccess, ) = seller.call{value: transferValue}("");
        require(valueSuccess, "Value Transfer Failed.");
        emit itemSold(_id, msg.sender, msg.value, transferValue);
    }

    function finalizeBid(BidVoucher calldata voucher, address _winner) public {
        address signer = _verify(voucher);
        address tokenAddress = itemsForSale[voucher.marketId].tokenAddress;
        address seller = itemsForSale[voucher.marketId].seller;
        uint256 tokenId = itemsForSale[voucher.marketId].tokenId;
        // make sure that the signature is valid
        require(signer == _winner, "Signature invalid or unauthorized");
        require(
            voucher.bid >= itemsForSale[voucher.marketId].askingPrice,
            "bid amount is lesser than min. price"
        );
        require(_winner != seller, "seller can't purchase created Item");

        require(tokenId == voucher.tokenId, "unexpected tokenId");

        require(
            tokenAddress == voucher.tokenAddress,
            "unexpected token Address"
        );

        require(!itemsForSale[voucher.marketId].isSold, "Item already sold");

        require(
            !itemsForSale[voucher.marketId].cancelled,
            "Item sale cancelled"
        );

        IERC20 WRAPPED = IERC20(WRAPPED_ADDRESS);
        require(
            WRAPPED.balanceOf(_winner) >= voucher.bid,
            "Not enough WETH in the winner address"
        );
        itemsForSale[voucher.marketId].isSold = true;

        activeItems[tokenAddress][tokenId] = false;
        IERC721(tokenAddress).safeTransferFrom(
            seller,
            _winner,
            tokenId
        );
        uint256 transferValue = (voucher.bid * 975) / 1000;
        WRAPPED.transferFrom(
            _winner,
            seller,
            transferValue
        );
        emit itemSold(voucher.marketId, _winner, voucher.bid, transferValue);
    }

    function cancelSale(uint256 id) public ItemExists(id) IsCancelled(id) {
        itemsForSale[id].cancelled = true;
        emit saleCancelled(id);
    }

    function _verify(BidVoucher calldata voucher)
        internal
        view
        returns (address)
    {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
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
