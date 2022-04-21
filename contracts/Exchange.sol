pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// @title Uniswap V1 Exchange
contract Exchange {
    address public tokenAddress;

    uint256 public totalSupply;
    mapping(address => uint256) public balances;

    event AddLiquidity(
        address provider,
        uint256 ethAmount,
        uint256 tokenAmount
    );
    event Transfer(address from, address to, uint256 amount);
    event RemoveLiquidity(address from, uint256 ethAmount, uint256 tokenAmount);
    event TokenPurchase(address buyer, uint ethSold, uint tokenBought);

    fallback() external payable {
        // TODO: ethToTokenInput(msg.value, 1, block.timestamp, msg.sender, msg.sender);
    }

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
    function addLiquidity(
        uint256 minLiquidity,
        uint256 maxTokens,
        uint256 deadline
    ) public payable returns (uint256) {
        require(deadline > block.timestamp, "The timelimit has passed");
        require(maxTokens > 0, "Number of tokens invalid");
        require(msg.value > 0, "ETH not sent");

        uint256 totalLiquidity = totalSupply;
        uint256 ethReserve = balances[address(this)] - msg.value;
        IERC20 token = IERC20(tokenAddress);
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 tokenAmount = (msg.value * tokenReserve) / ethReserve + 1;
        uint256 liquidityMinted = (msg.value * totalLiquidity) / ethReserve;
        require(maxTokens >= tokenAmount, "Exceeds maximum limit");
        require(
            liquidityMinted >= minLiquidity,
            "The minimum liquidy amount is not met"
        );
        balances[msg.sender] += liquidityMinted;
        totalSupply = totalLiquidity + minLiquidity; // TODO: Use SafeMath?
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
    function removeLiquidity(
        uint256 amount,
        uint256 minEth,
        uint256 minTokens,
        uint256 deadline
    ) public returns (uint256, uint256) {
        require(amount > 0, "Burn amount must be greater than 0");
        require(deadline > block.timestamp, "The timelimit has passed");
        require(minEth > 0, "ETH amount must be greater than 0");

        uint256 totalLiquidity = totalSupply;
        require(totalLiquidity > 0, "There is no liquidity to remove");
        IERC20 token = IERC20(tokenAddress);
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 ethAmount = (amount * balances[address(this)]) / totalLiquidity; // TODO: Should this balance be a separate variable for ETH from tokens balance?
        uint256 tokenAmount = (amount * tokenReserve) / totalLiquidity;
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

    /** @dev Price function for converting between ETH and tokens
     *   @param inputAmount Amount of ETH or tokens sold
     *   @param inputReserve Amount of input ETH or tokens in exchange reserves
     *   @param outputReserve Amount of output ETH or tokens in exchange reserves
     *   @return Amount of ETH or tokens bought
     **/
    function getInputPrice(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) private pure returns (uint256) {
        require(inputReserve > 0, "Not enough in reserves");
        require(outputReserve > 0, "Not enough in reserves");

        uint256 inputAmountWithFee = inputAmount * 997;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 1000) + inputAmountWithFee;
        return numerator / denominator;
    }

    /** @dev Price function for converting between ETH and tokens
     *   @param outputAmount Amount of ETH or tokens bought
     *   @param inputReserve Amount of input ETH or tokens in exchange reserves
     *   @param outputReserve Amount of output ETH or tokens in exchange reserves
     *   @return Amount of ETH or tokens bought
     **/
    function getOutputPrice(
        uint256 outputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) private pure returns (uint256) {
        require(inputReserve > 0, "Not enough in reserves");
        require(outputReserve > 0, "Not enough in reserves");
        uint256 numerator = inputReserve * outputReserve * 1000;
        uint256 denominator = (outputReserve - outputAmount) * 997;
        return numerator / denominator + 1;
    }

    /** @dev Convert ETH to tokens
    *   @param ethSold Amount of ETH sold in wei
    *   @param minTokens
    *   @param deadline
    *   @param buyer
    *   @param receipient
    **/
    function ethToTokenInput(
        uint ethSold,
        uint minTokens,
        uint deadline,
        address buyer,
        address recipient
    ) private returns (uint) {
        require(deadline > block.timestamp, "The timelimit has passed");
        require(ethSold > 0, "Invalid value for ETH amount");
        require(minTokens > 0, "Amount of tokens must be greater than 0");

        uint tokenReserve = balances[address(this)]; // TODO: double check
        uint ethBalance; //TODO: selfbalance
        uint tokensBought = getInputPrice(ethSold, ethBalance - ethSold, tokenReserve);
        
        require(tokensBought >= minTokens);
        IERC20 token = IERC20(tokenAddress);
        token.transfer(recipient, tokensBought);

        emit TokenPurchase(buyer, ethSold, tokensBought);

        return tokensBought;
    }

    function ethToTokenSwap() public payable {}

    function ethToTokenTransferInput() public payable {}

    function ethToTokenSwapOutput() public payable {}

    function ethToTokenTransferOutput() public payable {}

    function tokenToEthSwapInput() public {}

    function tokenToEthTransferInput() public {}

    function tokenToEthSwapOutput() public {}

    function tokenToEthTransferOutput() public {}

    function tokenToTokenSwapInput() public {}

    function tokenToTokenTransferInput() public {}

    function tokenToTokenSwapOutput() public {}

    function tokenToTokenTransferOutput() public {}

    function tokenToExchangeSwapInput() public {}

    function tokenToExchangeTransferInput() public {}

    function tokenToExchangeSwapOutput() public {}

    function tokenToExchangeTransferOutput() public {}

    function getEthToTokenInputPrice() public {}

    function getEthToTokenOutputPrice() public {}

    function getTokenToEthInputPrice() public {}

    function getTokenToEthOutputPrice() public {}
}
