const token = artifacts.require("Token");
const exchange = artifacts.require("Exchange");

module.exports = async function (deployer) {

    /*
    // Deploy Token contract first
    await deployer.deploy(token, "Hazel", "HAZ", (10 ** 18).toString());

    const tokenInstance = await token.deployed();
    console.log("Token address: " + tokenInstance.address);

    deployer.deploy(exchange, tokenInstance.address);

    const exchangeInstance = await exchange.deployed();
    console.log("Exchange address: " + exchangeInstance.address);*/


    // Deploy A, then deploy B, passing in A's newly deployed address
    deployer.deploy(token, "Hazel", "HAZ", (10 ** 18).toString()).then(function() {
        return deployer.deploy(exchange, token.address);
    });
  
};
