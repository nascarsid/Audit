const { ok } = require("assert");
const assert = require("assert");
const { ethers } = require("ethers");
const lazyNFT = artifacts.require("VizvaLazyNFT_V1");
const proxyContract = artifacts.require("LazyNFTProxy");
const { LazyMinter } = require("../test/LazyMinter.test");

const wallets = ethers.Wallet.fromMnemonic(
  "maple section rate kid degree still notable shaft room skull news lens"
);

let lazyNFTInstance;
let VizvaLazyNFTProxyInstance;
beforeEach(async () => {
  VizvaLazyNFTProxyInstance = await proxyContract.deployed();
  lazyNFTInstance = await lazyNFT.at(VizvaLazyNFTProxyInstance.address);
});

contract("lazyNFT test", async (accounts) => {
  it("should redeem an nft from signed voucher", async () => {
    const chainIdBN = await lazyNFTInstance.getChainID();
    const chainInWei = web3.utils.fromWei(chainIdBN, "ether");
    const chainId = await ethers.utils.parseUnits(chainInWei);
    //console.log('accounts',chainId,chainIdBN.toString(),chainInWei)
    const lazyMinter = new LazyMinter({
      contract: lazyNFTInstance,
      signer: wallets,
      chainId,
    });
    const voucher = await lazyMinter.createVoucher(
      1,
      "ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
    );
    const redeem = await lazyNFTInstance.redeem(
      accounts[1],
      voucher,
      accounts[0]
    );
    assert(ok);
  });

  it("Should fail if buy price is less than sell price plus commission", async function () {
    try {
      const chainIdBN = await lazyNFTInstance.getChainID();
      const chainInWei = web3.utils.fromWei(chainIdBN, "ether");
      const chainId = await ethers.utils.parseUnits(chainInWei);
      const lazyMinter = new LazyMinter({
        contract: lazyNFTInstance,
        signer: wallets,
        chainId,
      });
      const minPrice = await web3.utils.toWei("1", "ether");
      const voucher = await lazyMinter.createVoucher(
        2,
        "ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi",
        minPrice
      );
      const redeem = await lazyNFTInstance.redeem(
        accounts[1],
        voucher,
        accounts[0],
        { from: accounts[1], value: minPrice }
      );
      assert.fail("not thrown error");
    } catch (error) {
      assert.strictEqual(
        "Returned error: VM Exception while processing transaction: revert Insufficient funds to redeem -- Reason given: Insufficient funds to redeem.",
        error.message
      );
    }
  });

  it("Should trannfer payment to minter and commission to contract", async function () {
    const chainIdBN = await lazyNFTInstance.getChainID();
    const chainInWei = web3.utils.fromWei(chainIdBN, "ether");
    const chainId = await ethers.utils.parseUnits(chainInWei);
    const lazyMinter = new LazyMinter({
      contract: lazyNFTInstance,
      signer: wallets,
      chainId,
    });
    const minPrice = await web3.utils.toWei("1", "ether");
    const voucher = await lazyMinter.createVoucher(
      2,
      "ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi",
      minPrice
    );
    const previousBalanace = await web3.eth.getBalance(accounts[0]);
    const buyPrice = await web3.utils.toWei("1.025", "ether");
    const redeem = await lazyNFTInstance.redeem(
      accounts[1],
      voucher,
      accounts[0],
      { from: accounts[1], value: buyPrice }
    );
    const newBalance = await web3.eth.getBalance(accounts[0]);
    const contractBalance = await web3.eth.getBalance(VizvaLazyNFTProxyInstance.address)
    assert.strictEqual(contractBalance,web3.utils.toWei("0.025","ether"),"contract balance not as expected")
    assert.strictEqual(parseInt(minPrice), newBalance - previousBalanace);
  });
});
