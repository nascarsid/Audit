//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.2;
pragma abicoder v2; // required to accept structs as function parameters

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract VizvaLazyNFT_V1 is
    ERC721URIStorageUpgradeable,
    EIP712Upgradeable,
    AccessControlUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    // Represent the percentage of share for the contract.
    uint16 public commission; 

    // address to which withdraw function transfers funds.
    address public WALLET;

    ///Represents an un-minted NFT, which has not yet been recorded into the blockchain. A signed voucher can be redeemed for a real NFT using the redeem function.
    struct NFTVoucher {
        uint256 tokenId;
        uint256 minPrice;
        uint16 royalty;
        string uri;
        bytes signature;
    }

    //represent the event emited after redeeming a voucher
    event NFTRedeemed(
        uint256 tokenId,
        uint256 transferValue,
        uint256 commissionValue,
        address creator,
        address buyer
    );
    // string private constant SIGNING_DOMAIN = "VIZVANFT-Voucher";
    // string private constant SIGNATURE_VERSION = "1";
    //uint256 private commission = 25;

    constructor() initializer {}

    function __VizvaLazyNFT_V1_init(
        uint16 _commission,
        string memory name,
        string memory symbol,
        address _wallet,
        string memory SIGNING_DOMAIN,
        string memory SIGNATURE_VERSION
    ) public initializer {
        __ERC721_init(name, symbol);
        __Ownable_init_unchained();
        __Pausable_init_unchained();
        __EIP712_init(SIGNING_DOMAIN, SIGNATURE_VERSION);
        __VizvaLazyNFT_V1_init_unchained(_commission, _wallet);
    }

    function __VizvaLazyNFT_V1_init_unchained(
        uint16 _commission,
        address _wallet
    ) internal onlyInitializing {
        commission = _commission;
        WALLET = _wallet;
    }

    /// @notice Redeems an NFTVoucher for an actual NFT, creating it in the process.
    /// @param redeemer The address of the account which will receive the NFT upon success.
    /// @param voucher A signed NFTVoucher that describes the NFT to be redeemed.
    function redeem(
        address redeemer,
        NFTVoucher calldata voucher,
        address creator
    ) public payable nonReentrant returns (uint256) {
        // make sure signature is valid and get the address of the signer
        address signer = _verify(voucher);

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
        _mint(signer, voucher.tokenId);
        _setTokenURI(voucher.tokenId, voucher.uri);

        // transfer the token to the redeemer
        _transfer(signer, redeemer, voucher.tokenId);

        //calculating commission
        uint256 commissionValue = (commission * voucher.minPrice) / 1000;

        //canculating transfer value
        uint256 transferAmount = msg.value - commissionValue;

        //transfering value to creator
        (bool success, ) = signer.call{value: transferAmount}("");
        require(success, "Transfer failed.");

        //emitting redeem event
        emit NFTRedeemed(
            voucher.tokenId,
            transferAmount,
            commissionValue,
            signer,
            _msgSender()
        );

        //returning tokenId
        return voucher.tokenId;
    }

    function withdraw(uint256 amount) external virtual onlyOwner {
        require(
            address(this).balance <= amount,
            "amount should be less than avalable balance"
        );
        (bool success, ) = WALLET.call{value: amount}("");
        require(success, "Value Transfer Failed.");
    }

    /// @notice Returns a hash of the given NFTVoucher, prepared using EIP712 typed data hashing rules.
    /// @param voucher An NFTVoucher to hash.
    function _hash(bytes memory voucher)
        internal
        view
        returns (bytes32)
    {
        return
            _hashTypedDataV4(
                keccak256(
                    voucher
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

    /// @notice Verifies the signature for a given NFTVoucher, returning the address of the signer.
    /// @dev Will revert if the signature is invalid. Does not verify that the signer is authorized to mint NFTs.
    /// @param voucher An NFTVoucher describing an unminted NFT.
    function _verify(NFTVoucher calldata voucher)
        internal
        view
        returns (address)
    {
        bytes32 digest = _hash(abi.encode(
                        keccak256(
                            "NFTVoucher(uint256 tokenId,uint256 minPrice,uint16 royalty,string uri)"
                        ),
                        voucher.tokenId,
                        voucher.minPrice,
                        voucher.royalty,
                        keccak256(bytes(voucher.uri))
                    ));
        return ECDSAUpgradeable.recover(digest, voucher.signature);
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
