import { ethers } from "ethers";

// These constants must match the ones used in the smart contract.
const SIGNING_DOMAIN_NAME = "VIZVA_MARKETPLACE"
const SIGNING_DOMAIN_VERSION = "1"

interface domain {
  name: string,
  version: string,
  verifyingContract: string,
  chainId: ethers.BigNumberish,
}

interface initializer {
  contract: ethers.Contract,
  wallet: ethers.Wallet, 
  chainId: ethers.BigNumberish
}

/**
 * JSDoc typedefs.
 * 
 * @typedef {object} NFTVoucher
 * @property {ethers.BigNumber | number} tokenId the id of the un-minted NFT
 * @property {ethers.BigNumber | number} minPrice the minimum price (in wei) that the creator will accept to redeem this NFT.
 * @property {ethers.BigNumber | number} roylty percentage of share allotted to creator of the NFT.
 * @property {string} uri the metadata URI to associate with this NFT
 * @property {ethers.BytesLike} signature an EIP-712 signature of all fields in the NFTVoucher, apart from signature itself.
 */

/**
 * LazyMinter is a helper class that creates NFTVoucher objects and signs them, to be redeemed later by the LazyNFT contract.
 */
class LazyMinter {

  contract: ethers.Contract;
  wallet: ethers.Wallet;
  chainId: ethers.BigNumberish;
  _domain: domain | null;

  /**
   * Create a new LazyMinter targeting a deployed instance of the LazyNFT contract.
   * 
   * @param {Object} options
   * @param {ethers.Contract} contract an ethers Contract that's wired up to the deployed contract
   * @param {ethers.Wallet} wallet a wallet whose account is authorized to mint NFTs on the deployed contract
   */
  constructor(initializer:initializer) {
    this.contract = initializer.contract;
    this.wallet = initializer.wallet;
    this.chainId = initializer.chainId;
    this._domain = null
  }

  /**
   * Creates a new NFTVoucher object and signs it using this LazyMinter's signing key.
   * 
   * @param {ethers.BigNumber | number} tokenId the id of the un-minted NFT
   * @param {string} uri the metadata URI to associate with this NFT
   * @param {ethers.BigNumber | number} minPrice the minimum price (in wei) that the creator will accept to redeem this NFT. defaults to zero
   * @param {ethers.BigNumber | number} royalty the royalty (in number) % of the NFT price will credit to the creator. defaults to zero
   * 
   * @returns {NFTVoucher}
   */
  async createVoucher(tokenId: string, uri: string, minPrice = 0, royalty = 0) {
    const voucher = { tokenId, minPrice, royalty, uri }
    const domain = await this._signingDomain()
    const types = {
      NFTVoucher: [
        {name: "tokenId", type: "uint256"},
        {name: "minPrice", type: "uint256"},
        {name: "royalty", type: "uint16"},
        {name: "uri", type: "string"},  
      ]
    }
    const signature = await this.wallet._signTypedData(domain, types, voucher)
    return {
      ...voucher,
      signature,
    }
  }

  /**
   * @private
   * @returns {object} the EIP-721 signing domain, tied to the chainId of the wallet
   */
  async _signingDomain() {
    if (this._domain != null) {
      return this._domain
    }
    this._domain = {
      name: SIGNING_DOMAIN_NAME,
      version: SIGNING_DOMAIN_VERSION,
      verifyingContract: this.contract.address,
      chainId:this.chainId,
    }
    return this._domain
  }
}

module.exports = {
  LazyMinter
}