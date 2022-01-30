const proxyContract = artifacts.require("VizvaLazyNFTProxy");
const vizvaLazyNFTContract = artifacts.require("VizvaLazyNFT_V1");
const adminContract = artifacts.require("VizvaProxyAdmin");
const VizvaMarketProxy = artifacts.require("VizvaMarketProxy");

module.exports = async function (deployer) {
  const contract = new web3.eth.Contract(vizvaLazyNFTContract.abi);
  const data = contract.methods
    .__VizvaLazyNFT_V1_init(
      "VIZVA TOKEN",
      "VIZVA",
      VizvaMarketProxy.address
    )
    .encodeABI();
  //await deployer.deploy(adminContract);
  await deployer.deploy(vizvaLazyNFTContract);
  await deployer.deploy(
    proxyContract,
    vizvaLazyNFTContract.address,
    adminContract.address,
    data
  );
};
