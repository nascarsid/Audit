const marketContract = artifacts.require("VizvaMarket_V1");

module.exports = async function (deployer) {
  await deployer.deploy(marketContract);
};
