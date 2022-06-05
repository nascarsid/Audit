const { marketConfig } = require("../config/config");

const proxyContract = artifacts.require("VizvaMarketProxy");
const marketContract = artifacts.require("VizvaMarket_V1");
const adminContract = artifacts.require("VizvaProxyAdmin");
//const WETHContract = artifacts.require("WETH9"); //for testing

module.exports = async function (deployer) {
  //await deployer.deploy(WETHContract); // for tetsing
  const contract = new web3.eth.Contract(marketContract.abi);
  const data = contract.methods
    .__VizvaMarket_init(
      marketConfig._commission,
      web3.utils.toWei(marketConfig._minimumAskingPrice),
      marketConfig._wallet
    )
    .encodeABI();
  await deployer.deploy(
    proxyContract,
    marketContract.address,
    adminContract.address,
    data
  );
};
