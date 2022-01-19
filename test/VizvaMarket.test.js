const assert = require("assert");
const MarketProxyContract = artifacts.require("VizvaMarketProxy");
const Vizva721Proxy = artifacts.require("Vizva721Proxy");
const VizvaToken = artifacts.require("Vizva721");
const VizvaMarket = artifacts.require("VizvaMarket_V1");
const WETH = artifacts.require("WETH9");
const { LazyBidder } = require("./Bidder.test");
const { ethers } = require("ethers");

const wallets = ethers.Wallet.fromMnemonic(
  "kite invite rate speed green ladder cup fetch settle write jelly twice"
);

beforeEach(async () => {
  MarketProxyInstance = await MarketProxyContract.deployed();
  Vizva721ProxyInstance = await Vizva721Proxy.deployed();
  VizvaTokenInstance = await VizvaToken.at(Vizva721ProxyInstance.address);
  VizvaMarketInstance = await VizvaMarket.at(MarketProxyInstance.address);
  WETHInstance = await WETH.deployed();
});

contract("VIZVA MARKETPLACE TEST", (accounts) => {
  it("Market contract should initialize only once", async () => {
    try {
      await VizvaMarketInstance.__VizvaMarket_init(
        "0x7Adb261Bea663ee06E4ff0a657E65aE91aC7167f",
        "VIZVA_MARKETPLACE",
        "1"
      );
      assert.fail();
    } catch (error) {
      assert.strictEqual(
        error.message,
        "Returned error: VM Exception while processing transaction: revert Initializable: contract is already initialized -- Reason given: Initializable: contract is already initialized."
      );
    }
  });

  it("Token Contract should initialize only once", async () => {
    try {
      await VizvaTokenInstance.__VizvaToken_init("VIZVA TOKEN", "VIZVA");
      assert.fail();
    } catch (error) {
      assert.strictEqual(
        error.message,
        "Returned error: VM Exception while processing transaction: revert Initializable: contract is already initialized -- Reason given: Initializable: contract is already initialized."
      );
    }
  });

  it("should return token initial call data", async () => {
    const name = await VizvaTokenInstance.name.call();
    const symbol = await VizvaTokenInstance.symbol.call();
    assert.strictEqual("VIZVA TOKEN", name);
    assert.strictEqual("VIZVA", symbol);
  });

  it("should create new token", async () => {
    const newToken = await VizvaTokenInstance.createItem(
      "ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
    );
    const from = newToken.logs[0].args["from"];
    const to = newToken.logs[0].args["to"];
    const tokenId = newToken.logs[0].args["tokenId"];
    assert.strictEqual("0x0000000000000000000000000000000000000000", from);
    assert.strictEqual(accounts[0], to);
    assert.strictEqual(1, parseInt(tokenId));
  });

  it("Vizva721 is Pausable", async () => {
    let paused = await VizvaTokenInstance.paused.call();
    assert.strictEqual(false, paused);
    await VizvaTokenInstance.pause();
    paused = await VizvaTokenInstance.paused.call();
    assert.ok(paused);
  });

  it("Vizva721 is UnPausable", async () => {
    let paused = await VizvaTokenInstance.paused.call();
    assert.strictEqual(true, paused);
    await VizvaTokenInstance.unpause();
    paused = await VizvaTokenInstance.paused.call();
    assert.ok(!paused);
  });

  it("should create new token and add it to market", async () => {
    const newToken = await VizvaTokenInstance.createItem(
      "ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
    );
    const tokenId = newToken.logs[0].args["tokenId"];
    const vizvaAddress = await MarketProxyInstance.address;
    const tokenAddress = await Vizva721ProxyInstance.address;
    await VizvaTokenInstance.setApprovalForAll(vizvaAddress, true);
    const marketData = await VizvaMarketInstance.addItemToMarket(
      1,
      web3.utils.toWei("1", "ether"),
      accounts[0],
      {
        tokenType: 1,
        royalty: 10,
        tokenId: parseInt(tokenId),
        amount:1,
        tokenAddress,
      }
    );
    assert.strictEqual(0, parseInt(marketData.logs[0].args["id"]));
    assert.strictEqual(2, parseInt(marketData.logs[0].args["tokenId"]));
    assert.strictEqual(tokenAddress, marketData.logs[0].args["tokenAddress"]);
    assert.strictEqual(
      1000000000000000000,
      parseInt(marketData.logs[0].args["askingPrice"])
    );
    assert.strictEqual(10, parseInt(marketData.logs[0].args["royalty"]));
    assert.strictEqual(accounts[0], marketData.logs[0].args["creator"]);
  });

  it("should allow token purchase", async () => {
    const Id = 0;
    const tokenId = 2;
    const tokenAddress = await Vizva721ProxyInstance.address;
    const marketData = await VizvaMarketInstance.buyItem(
      tokenAddress,
      tokenId,
      Id,
      {
        from: accounts[1],
        value: web3.utils.toWei("1", "ether"),
      }
    );
    const owner = await VizvaTokenInstance.ownerOf.call(2);
    assert.strictEqual(accounts[1], marketData.logs[0].args["buyer"]);
    assert.strictEqual(Id, parseInt(marketData.logs[0].args["id"]));
    assert.strictEqual(accounts[1], owner);
  });

  it("allow auction with seller as creator", async () => {
    const newToken = await VizvaTokenInstance.createItem(
      "ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi",
      { from: accounts[1] }
    );
    const tokenId = newToken.logs[0].args["tokenId"];
    const vizvaAddress = await MarketProxyInstance.address;
    const tokenAddress = await Vizva721ProxyInstance.address;
    await VizvaTokenInstance.setApprovalForAll(vizvaAddress, true, {
      from: accounts[1],
    });
    const marketData = await VizvaMarketInstance.addItemToMarket(
      2,
      web3.utils.toWei("1", "ether"),
      accounts[1],
      {
        tokenType: 1,
        royalty: 10,
        tokenId:parseInt(tokenId),
        amount:1,
        tokenAddress,
      },
      { from: accounts[1] }
    );
    await WETHInstance.deposit({
      from: accounts[0],
      value: web3.utils.toWei("1", "ether"),
    });
    await WETHInstance.approve(
      MarketProxyInstance.address,
      web3.utils.toWei("1", "ether"),
      { from: accounts[0] }
    );
    const WETHBalanceOwnerBefore = await WETHInstance.balanceOf.call(
      accounts[1]
    );
    const WETHBalanceBuyerBefore = await WETHInstance.balanceOf.call(
      accounts[0]
    );
    const marketId = parseInt(marketData.logs[0].args["id"]);
    const chainIdBN = await VizvaMarketInstance.getChainID();
    const chainInWei = web3.utils.fromWei(chainIdBN, "ether");
    const chainId = ethers.utils.parseUnits(chainInWei);

    const lazyBidder = new LazyBidder({
      contract: VizvaMarketInstance,
      signer: wallets,
      chainId,
    });

    const voucher = await lazyBidder.createBidVoucher(
      WETHInstance.address,
      tokenAddress,
      parseInt(tokenId),
      parseInt(marketId),
      web3.utils.toWei("1", "ether")
    );
    const previousOwner = await VizvaTokenInstance.ownerOf.call(tokenId);
    const result = await VizvaMarketInstance.finalizeBid(voucher, accounts[0]);
    const currentOwner = await VizvaTokenInstance.ownerOf.call(tokenId);
    const WETHBalanceOwnerAfter = await WETHInstance.balanceOf.call(
      accounts[1]
    );
    const WETHBalanceBuyerAfter = await WETHInstance.balanceOf.call(
      accounts[0]
    );
    const WETHBalanceWallet = await WETHInstance.balanceOf.call(
      "0x7Adb261Bea663ee06E4ff0a657E65aE91aC7167f"
    );
    assert.strictEqual(accounts[0], result.logs[0].args["buyer"]);
    assert.strictEqual(accounts[1], previousOwner);
    assert.strictEqual(accounts[0], currentOwner);
    assert.strictEqual(
      parseInt(WETHBalanceBuyerBefore).toString(),
      web3.utils.toWei("1", "ether")
    );
    assert.strictEqual(
      parseInt(WETHBalanceOwnerAfter).toString(),
      web3.utils.toWei("0.975", "ether")
    );
    assert.strictEqual(
      parseInt(WETHBalanceWallet).toString(),
      web3.utils.toWei("0.025", "ether")
    );
    assert.strictEqual(
      parseInt(WETHBalanceOwnerBefore),
      parseInt(WETHBalanceBuyerAfter)
    );
  });

  it("allow auction with different seller and creator", async () => {
    const newToken = await VizvaTokenInstance.createItem(
      "ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi",
      { from: accounts[3] }
    );
    const tokenId = newToken.logs[0].args["tokenId"];
    await VizvaTokenInstance.safeTransferFrom(
      accounts[3],
      accounts[4],
      tokenId,
      { from: accounts[3] }
    );
    const vizvaAddress = await MarketProxyInstance.address;
    const tokenAddress = await Vizva721ProxyInstance.address;
    await VizvaTokenInstance.setApprovalForAll(vizvaAddress, true, {
      from: accounts[4],
    });
    const marketData = await VizvaMarketInstance.addItemToMarket(
      2,
      web3.utils.toWei("1", "ether"),
      accounts[3],
      {
        tokenType: 1,
        royalty: 10,
        tokenId:parseInt(tokenId),
        amount:1,
        tokenAddress,
      },
      { from: accounts[4] }
    );
    await WETHInstance.deposit({
      from: accounts[0],
      value: web3.utils.toWei("1", "ether"),
    });
    await WETHInstance.approve(
      MarketProxyInstance.address,
      web3.utils.toWei("1", "ether"),
      { from: accounts[0] }
    );
    const WETHBalanceOwnerBefore = await WETHInstance.balanceOf.call(
      accounts[4]
    );
    const WETHBalanceBuyerBefore = await WETHInstance.balanceOf.call(
      accounts[0]
    );
    const marketId = parseInt(marketData.logs[0].args["id"]);
    const chainIdBN = await VizvaMarketInstance.getChainID();
    const chainInWei = web3.utils.fromWei(chainIdBN, "ether");
    const chainId = ethers.utils.parseUnits(chainInWei);

    const lazyBidder = new LazyBidder({
      contract: VizvaMarketInstance,
      signer: wallets,
      chainId,
    });

    const voucher = await lazyBidder.createBidVoucher(
      WETHInstance.address,
      tokenAddress,
      parseInt(tokenId),
      parseInt(marketId),
      web3.utils.toWei("1", "ether")
    );
    const previousOwner = await VizvaTokenInstance.ownerOf.call(tokenId);
    const result = await VizvaMarketInstance.finalizeBid(voucher, accounts[0]);
    const currentOwner = await VizvaTokenInstance.ownerOf.call(tokenId);
    const WETHBalanceOwnerAfter = await WETHInstance.balanceOf.call(
      accounts[4]
    );
    const WETHBalanceBuyerAfter = await WETHInstance.balanceOf.call(
      accounts[0]
    );
    const WETHBalanceCreator = await WETHInstance.balanceOf.call(accounts[3]);
    const WETHBalanceWallet = await WETHInstance.balanceOf.call(
      "0x7Adb261Bea663ee06E4ff0a657E65aE91aC7167f"
    );
    assert.strictEqual(accounts[0], result.logs[0].args["buyer"]);
    assert.strictEqual(accounts[4], previousOwner);
    assert.strictEqual(accounts[0], currentOwner);
    assert.strictEqual(
      parseInt(WETHBalanceBuyerBefore).toString(),
      web3.utils.toWei("1", "ether")
    );
    assert.strictEqual(
      parseInt(WETHBalanceOwnerAfter).toString(),
      web3.utils.toWei("0.875", "ether")
    );
    assert.strictEqual(
      parseInt(WETHBalanceWallet).toString(),
      web3.utils.toWei("0.05", "ether") //wallet already has 0.025 WETH
    );
    assert.strictEqual(
      parseInt(WETHBalanceCreator).toString(),
      web3.utils.toWei("0.1", "ether")
    );
    assert.strictEqual(
      parseInt(WETHBalanceOwnerBefore),
      parseInt(WETHBalanceBuyerAfter)
    );
  });
});
