const assert = require("assert");
const collectionContract = artifacts.require("VizvaCollectionClone");
const VizvaMarket = artifacts.require("VizvaMarket_V1");
const MarketProxyContract = artifacts.require("VizvaMarketProxy");
const ERC721 = artifacts.require("ERC721NFT");

let MarketProxyInstance;
let VizvaMarketInstance;
let CollectionInstance;
let VizvaTokenInstance;
let event;

beforeEach(async () => {
  MarketProxyInstance = await MarketProxyContract.deployed();
  VizvaMarketInstance = await VizvaMarket.at(MarketProxyInstance.address);
  CollectionInstance = await collectionContract.deployed();
  const CollectionReceipt = await CollectionInstance.createERC721Collection(
    "NewCollection",
    "NC"
  );
  event = CollectionReceipt.logs.find(
    (data) => data.event == "NewERC721CollectionCreated"
  );
  VizvaTokenInstance = await ERC721.at(event.args.clone);
});

contract("VIZVA COLLECTION TEST", (accounts) => {
  it("should return collection initial call data", async () => {
    const marketAddress = await CollectionInstance.getMarketAddress();
    assert.strictEqual(marketAddress, MarketProxyInstance.address);
  });

  it("should create new collection", async () => {
    assert.strictEqual(event.args.owner, accounts[0]);
  });

  it("Token Contract should initialize only once", async () => {
    try {
      await VizvaTokenInstance.__ERC721NFT_init(
        "NewCollection",
        "NC",
        accounts[0],
        MarketProxyInstance.address
      );
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
    assert.strictEqual("NewCollection", name);
    assert.strictEqual("NC", symbol);
  });

  it("should create new token by the owner", async () => {
    const newToken = await VizvaTokenInstance.createItem(
      "ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
    );
    console.log(`single mint gas used: ${newToken.receipt.gasUsed}`);
    const from = newToken.logs[0].args["from"];
    const to = newToken.logs[0].args["to"];
    const tokenId = newToken.logs[0].args["tokenId"];
    assert.strictEqual("0x0000000000000000000000000000000000000000", from);
    assert.strictEqual(accounts[0], to);
    assert.strictEqual(1, parseInt(tokenId));
  });

  it("should create new token and add it to market", async () => {
    const newToken = await VizvaTokenInstance.createItem(
      "ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
    );
    const tokenId = newToken.logs[0].args["tokenId"];
    const vizvaAddress = await MarketProxyInstance.address;
    const tokenAddress = event.args.clone;
    await VizvaTokenInstance.setApprovalForAll(vizvaAddress, true);
    const marketData = await VizvaMarketInstance.addItemToMarket(
      1,
      web3.utils.toWei("1", "ether"),
      {
        tokenType: 1,
        royalty: 10,
        tokenId: parseInt(tokenId),
        amount: 1,
        tokenAddress,
        creator: accounts[0],
      }
    );
    assert.strictEqual(0, parseInt(marketData.logs[0].args["id"]), "market Id");
    assert.strictEqual(
      1,
      parseInt(marketData.logs[0].args["tokenId"]),
      "token id"
    );
    assert.strictEqual(
      tokenAddress,
      marketData.logs[0].args["tokenAddress"],
      "token Address"
    );
    assert.strictEqual(
      1000000000000000000,
      parseInt(marketData.logs[0].args["askingPrice"]),
      "asking price"
    );
    assert.strictEqual(
      accounts[0],
      marketData.logs[0].args["creator"],
      "creator"
    );
  });

  it("should allow token purchase", async () => {
    const newToken = await VizvaTokenInstance.createItem(
        "ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
      );
      const tokenId = newToken.logs[0].args["tokenId"];
      const vizvaAddress = await MarketProxyInstance.address;
      const tokenAddress = event.args.clone;
      await VizvaTokenInstance.setApprovalForAll(vizvaAddress, true);
      const saleData = await VizvaMarketInstance.addItemToMarket(
        1,
        web3.utils.toWei("1", "ether"),
        {
          tokenType: 1,
          royalty: 10,
          tokenId: parseInt(tokenId),
          amount: 1,
          tokenAddress,
          creator: accounts[0],
        }
      );
    const Id = parseInt(saleData.logs[0].args["id"]);
    const marketData = await VizvaMarketInstance.buyItem(
      tokenAddress,
      tokenId,
      Id,
      {
        from: accounts[1],
        value: web3.utils.toWei("1", "ether"),
      }
    );
    const owner = await VizvaTokenInstance.ownerOf.call(parseInt(tokenId));
    const contractBalance = await web3.eth.getBalance(
      MarketProxyInstance.address
    );
    assert.strictEqual(
      accounts[1],
      marketData.logs[0].args["buyer"],
      "buyer mismatch"
    );
    assert.strictEqual(contractBalance, web3.utils.toWei("0.025", "ether"));
    assert.strictEqual(Id, parseInt(marketData.logs[0].args["id"]));
    assert.strictEqual(accounts[1], owner);
  });
});
