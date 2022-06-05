const { vizva721Config } = require("../config/config");

const proxyContract = artifacts.require("Vizva721Proxy");
const vizva721Contract = artifacts.require("Vizva721");
const adminContract = artifacts.require("VizvaProxyAdmin");

module.exports = async function (deployer) {
  const contract = new web3.eth.Contract(vizva721Contract.abi);
  const data = contract.methods
    .__VizvaToken_init(vizva721Config._name, vizva721Config._symbol)
    .encodeABI();
  await deployer.deploy(
    proxyContract,
    vizva721Contract.address,
    adminContract.address,
    data
  );
};
