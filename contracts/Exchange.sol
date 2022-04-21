pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


// @title Uniswap V1 Exchange 
contract Exchange {

    address public tokenAddress;

    uint public totalSupply;
    mapping(address => uint) public balances;

    event AddLiquidity(address provider, uint ethAmount, uint tokenAmount);
    event Transfer(address from, address to, uint amount);
    event RemoveLiquidity(address from, uint ethAmount, uint tokenAmount);

    /** @dev Instead of setUp function, use constructor
    *   @param _tokenAddress Address of ERC20 token sold on exchange
    **/
    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "Token Address is not valid.");
        tokenAddress = _tokenAddress;
    }

    /** @dev Add liquidity within the bounds and emit Add and Transfer events
    *   @param minLiquidity Minimum liquidity minted
    *   @param maxTokens Max tokens added
    *   @param deadline Transaction deadline
    *   @return uint The amount of liquidity tokens minted
    **/
    function addLiquidity(uint minLiquidity, uint maxTokens, uint deadline) public payable returns(uint) {
        require(deadline > block.timestamp, "The timelimit has passed");
        require(maxTokens > 0, "Number of tokens invalid");
        require(msg.value > 0, "ETH not sent");

        uint totalLiquidity = totalSupply;
        uint ethReserve = balances[address(this)] - msg.value;
        IERC20 token = IERC20(tokenAddress);
        uint tokenReserve = token.balanceOf(address(this));
        uint tokenAmount = msg.value * tokenReserve / ethReserve + 1;
        uint liquidityMinted = msg.value * totalLiquidity / ethReserve;
        require(maxTokens >= tokenAmount, "Exceeds maximum limit");
        require(liquidityMinted >= minLiquidity, "The minimum liquidy amount is not met");
        balances[msg.sender] += liquidityMinted; 
        totalSupply = totalLiquidity + minLiquidity; // Use SafeMath?
        token.transferFrom(msg.sender, address(this), tokenAmount);

        emit AddLiquidity(msg.sender, msg.value, tokenAmount);
        emit Transfer(tokenAddress, msg.sender, liquidityMinted);

        return liquidityMinted;

    }

    /** @dev Burn tokens when removing liquidity within the bounds
    *   @param amount The burn amount of UNI
    *   @param minEth   Minimum ETH removed
    *   @param minTokens Minimum ERC20 tokens removed
    *   @param deadline Transaction deadline
    *   @return uint The amount of ETH removed
    *   @return uint The amount of ERC20 tokens removed
    **/
    function removeLiquidity(uint amount, uint minEth, uint minTokens, uint deadline) public returns(uint, uint) {
        require(amount > 0, "Burn amount must be greater than 0");
        require(deadline > block.timestamp, "The timelimit has passed");
        require(minEth > 0, "ETH amount must be greater than 0");

        uint totalLiquidity = totalSupply;
        require(totalLiquidity > 0, "There is no liquidity to remove");
        IERC20 token = IERC20(tokenAddress);
        uint tokenReserve = token.balanceOf(address(this));
        uint ethAmount = amount * balances[address(this)] / totalLiquidity; // Should this balance be a separate variable for ETH from tokens balance?
        uint tokenAmount = amount * tokenReserve / totalLiquidity;
        require(ethAmount >= minEth, "Minimum ETH amount not met");
        require(tokenAmount >= minTokens, "Minimum token amount not met");
        balances[msg.sender] -= amount;
        totalSupply = totalLiquidity - amount;
        payable(msg.sender).transfer(ethAmount);
        token.transferFrom(msg.sender, address(this), tokenAmount);
        
        emit RemoveLiquidity(msg.sender, ethAmount, tokenAmount);
        emit Transfer(tokenAddress, msg.sender, amount);

        return (ethAmount, tokenAmount);
    }

}