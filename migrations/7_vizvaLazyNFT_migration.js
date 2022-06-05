const vizvaLazyNFTContract = artifacts.require("VizvaLazyNFT_V1");

module.exports = async function (deployer) {
  await deployer.deploy(vizvaLazyNFTContract);
};
