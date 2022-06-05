const vizva721Contract = artifacts.require("Vizva721");

module.exports = async function (deployer) {
  await deployer.deploy(vizva721Contract);
};
