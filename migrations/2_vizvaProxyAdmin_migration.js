const adminContract = artifacts.require("VizvaProxyAdmin");

module.exports = async function (deployer) {
  await deployer.deploy(adminContract);
};