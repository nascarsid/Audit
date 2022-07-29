const VizvaCollectionClone = artifacts.require("VizvaCollectionClone");
const MarketProxyContract = artifacts.require("VizvaMarketProxy");

module.exports = async function (deployer) {
  await deployer.deploy(VizvaCollectionClone, MarketProxyContract.address);
};
