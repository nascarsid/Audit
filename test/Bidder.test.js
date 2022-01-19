const ethers = require("ethers");

// These constants must match the ones used in the smart contract.
const SIGNING_DOMAIN_NAME = "VIZVA_MARKETPLACE";
const SIGNING_DOMAIN_VERSION = "1";

/**
 * JSDoc typedefs.
 *
 * @typedef {object} BidVoucher
 * @property {ethers.Addresses } asset  the address of the wrapped token
 * @property {ethers.Addresses } tokenAddress  the address of the buying token
 * @property {ethers.BigNumber | number} tokenId the id of the NFT wish to purchase.
 * @property {ethers.BigNumber | number} bid the amount  (in wei) that the bidder ready to pay.
 * @property {ethers.BytesLike} signature an EIP-712 signature of all fields in the BidVoucher, apart from signature itself.
 */

class LazyBidder {
  /**
   * Create a new LazyBidder targeting a deployed instance of the Vizva Marketplace contract.
   *
   * @param {Object} options
   * @param {ethers.Contract} contract an ethers Contract that's wired up to the deployed contract
   * @param {ethers.Signer} signer a Signer whose account is authorized to mint NFTs on the deployed contract
   */
  constructor({ contract, signer, chainId }) {
    this.contract = contract;
    this.signer = signer;
    this.chainId = chainId;
  }
  /**
   * Creates a new BidVoucher object and signs it using this LazyBidder's signing key.
   *
   * @property {ethers.Address } asset  the address of the wrapped token
   * @property {ethers.Address } tokenAddress  the address of the buying token
   * @param {ethers.BigNumber | number} tokenId the id of the un-minted NFT
   * @property {ethers.BigNumber | number} bid the amount  (in wei) that the bidder ready to pay.
   * @property {ethers.BytesLike} signature an EIP-712 signature of all fields in the NFTVoucher, apart from signature itself.
   *
   * @returns {NFTVoucher}
   */
  async createBidVoucher(asset, tokenAddress, tokenId, marketId, bid) {
    const voucher = { asset, tokenAddress, tokenId, marketId, bid };
    const domain = await this._signingDomain();
    const types = {
      BidVoucher: [
        { name: "asset", type: "address" },
        { name: "tokenAddress", type: "address" },
        { name: "tokenId", type: "uint256" },
        { name: "marketId", type: "uint256" },
        { name: "bid", type: "uint256" },
      ],
    };
    const signature = await this.signer._signTypedData(domain, types, voucher);
    return {
      ...voucher,
      signature,
    };
  }

  /**
   * @private
   * @returns {object} the EIP-721 signing domain, tied to the chainId of the signer
   */
  async _signingDomain() {
    if (this._domain != null) {
      return this._domain;
    }
    this._domain = {
      name: SIGNING_DOMAIN_NAME,
      version: SIGNING_DOMAIN_VERSION,
      verifyingContract: this.contract.address,
      chainId: this.chainId,
    };
    return this._domain;
  }
}

module.exports = {
  LazyBidder,
};
