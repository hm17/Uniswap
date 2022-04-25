const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Exchange", function () {
    let deployer, addr1, addr2;
    let token, exchange;
    let tokenName = "Hazel";
    let tokenSymbol = "HAZ";
    let tokenInitialSupply = (100 * (10 ** 18)).toString();

    beforeEach(async function () {
        // Get signers
        [deployer, addr1, addr2] = await ethers.getSigners();
        
        const Token = await ethers.getContractFactory("Token");
        token = await Token.deploy(tokenName, tokenSymbol, tokenInitialSupply);
        await token.deployed();
         
        const Exchange = await ethers.getContractFactory("Exchange");
        exchange = await Exchange.deploy(token.address);
    });

    it("Should create ERC20 token", async function () {
        expect(await token.name()).to.equal(tokenName);
        expect(await token.symbol()).to.equal(tokenSymbol);
        expect(await token.totalSupply()).to.equal(tokenInitialSupply);

        // deployer will have all the tokens minted
        expect(await token.balanceOf(deployer.address)).to.equal(tokenInitialSupply);
    })

    it("Should deploy an Exchange for the given ERC20 token", async function () {
        expect(await exchange.token()).to.equal(token.address);
    })

    it("Should create the liquidy token when deploying the Exchange", async function () {
        expect(await exchange.name()).to.equal("Uniswap-V1");
        expect(await exchange.symbol()).to.equal("UNI-V1");
        expect(await exchange.totalSupply()).to.equal(0);
    })

    xit("Should create a new liquidity pool when calling addLiquidity for the first time", async function () {
        const minLiquidity = 100;
        const maxTokens = 1;
        const deadline = 1; //TODO: How to pass the equivalent of block.latest in js
        const ethSent = 2;

        exchange.connect(deployer).addLiquidity(minLiquidity, maxTokens, deadline, {value: ethSent});

        //expect(await exchange.totalSupply()).to.equal(web3.utils.toWei(String(ethSent),'ether'));

        //expect(initialLiquidity).to.equal(web3.utils.toWei(String(ethSent),'ether'));
        //await expect(exchange.connect(deployer).addLiquidity(minLiquidity, maxTokens, deadline, {value: ethSent})).to.equal(web3.utils.toWei(String(ethSent),'ether'));
      
        
    })
}) 