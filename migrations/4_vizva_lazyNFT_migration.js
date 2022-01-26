const proxyContract = artifacts.require("LazyNFTProxy");
const vizvaLazyNFTContract = artifacts.require("VizvaLazyNFT_V1");
const adminContract = artifacts.require("VizvaProxyAdmin");

module.exports = async function (deployer) {
  const contract = new web3.eth.Contract(vizvaLazyNFTContract.abi);
  const data = contract.methods
    .__VizvaLazyNFT_V1_init(
      25,
      "VIZVA TOKEN",
      "VIZVA-L",
      "0x7Adb261Bea663ee06E4ff0a657E65aE91aC7167f",
      "VIZVA_MARKETPLACE",
      "1"
    )
    .encodeABI();
  await deployer.deploy(adminContract);
  await deployer.deploy(vizvaLazyNFTContract);
  await deployer.deploy(
    proxyContract,
    vizvaLazyNFTContract.address,
    adminContract.address,
    data
  );
};
