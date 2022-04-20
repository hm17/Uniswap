pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


// @title Uniswap V1 Exchange 
contract Exchange {

    address public tokenAddress;

    uint public totalSupply;
    mapping(address => uint) public balances;

    event AddLiquidity(address provider, uint ethAmount, uint tokenAmount);
    event Transfer(address from, address to, uint amount);

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
    *   @return The amount of liquidity tokens minted
     */
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

}