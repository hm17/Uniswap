const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Exchange", function () {
    it("Should add liquidity", async function () {
        const Token = await ethers.getContractFactory("Token");
        token = await Token.deploy("UNISWAP-V1", "UNI-V1", (10 ** 18).toString());
        await token.deployed();

        const Exchange = await ethers.getContractFactory("Exchange");
        const exchange = await Exchange.deploy(token.address);
    })
})