const proxyContract = artifacts.require("VizvaMarketProxy");
const marketContract = artifacts.require("VizvaMarket_V1");
const adminContract = artifacts.require("VizvaProxyAdmin");
const WETHContract = artifacts.require("WETH9")

module.exports = async function(deployer){
    await deployer.deploy(WETHContract);
    const contract = new web3.eth.Contract(marketContract.abi)
    const data = contract.methods.__VizvaMarket_init("0x7Adb261Bea663ee06E4ff0a657E65aE91aC7167f",WETHContract.address,"VIZVA_MARKETPLACE","1").encodeABI();
    await deployer.deploy(adminContract);
    await deployer.deploy(marketContract);
    await deployer.deploy(proxyContract,marketContract.address,adminContract.address,data);
}