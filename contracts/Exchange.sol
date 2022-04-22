pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// @title Uniswap V1 Exchange
// @author Hazel Madolid
contract Exchange {

    // Address of ERC20 token sold on this exchange
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
    event TokenPurchase(address buyer, uint256 ethSold, uint256 tokenBought);
    event EthPurchase(address buyer, uint tokensSold, uint weiBought);

    fallback() external payable {
        ethToTokenInput(msg.value, 1, block.timestamp, msg.sender, msg.sender);
    }

    /** @dev Instead of setUp function, use constructor
     *   @param _tokenAddress Address of ERC20 token sold on exchange
     **/
    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "Token address is not valid.");
        tokenAddress = _tokenAddress;
    }

    /** @dev Returns the token balance of the Exchange */
    function getReserve() public view returns(uint) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    function transferTokens(address from, address to, uint tokenAmount) private {
        IERC20 token = IERC20(tokenAddress);
        token.transferFrom(msg.sender, address(this), tokenAmount);
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
        uint256 tokenReserve = getReserve();
        uint256 tokenAmount = (msg.value * tokenReserve) / ethReserve + 1;
        uint256 liquidityMinted = (msg.value * totalLiquidity) / ethReserve;
        require(maxTokens >= tokenAmount, "Exceeds maximum limit");
        require(
            liquidityMinted >= minLiquidity,
            "The minimum liquidy amount is not met"
        );
        balances[msg.sender] += liquidityMinted;
        totalSupply = totalLiquidity + minLiquidity; // TODO: Use SafeMath?
        transferTokens(msg.sender, address(this), tokenAmount);

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
        uint256 tokenReserve = getReserve();
        uint256 ethAmount = (amount * balances[address(this)]) / totalLiquidity; // TODO: Should this balance be a separate variable for ETH from tokens balance?
        uint256 tokenAmount = (amount * tokenReserve) / totalLiquidity;
        require(ethAmount >= minEth, "Minimum ETH amount not met");
        require(tokenAmount >= minTokens, "Minimum token amount not met");
        balances[msg.sender] -= amount;
        totalSupply = totalLiquidity - amount;
        payable(msg.sender).transfer(ethAmount);
        transferTokens(msg.sender, address(this), tokenAmount);

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

    function ethToTokenInput(
        uint256 ethSold,
        uint256 minTokens,
        uint256 deadline,
        address buyer,
        address recipient
    ) private returns (uint256) {
        require(deadline > block.timestamp, "The timelimit has passed");
        require(ethSold > 0, "Invalid value for ETH amount");
        require(minTokens > 0, "Amount of tokens must be greater than 0");

        uint256 tokenReserve = getReserve();
        uint256 ethBalance; //TODO: selfbalance balances[address(this)]; 
        uint256 tokensBought = getInputPrice(
            ethSold,
            ethBalance - ethSold,
            tokenReserve
        );

        require(tokensBought >= minTokens);
        transferTokens(msg.sender, recipient, tokensBought); // TODO: double check is from buyer or msg.sender?

        emit TokenPurchase(buyer, ethSold, tokensBought);

        return tokensBought;
    }

    /** @dev Convert ETH to tokens
     **/
    function ethToTokenSwapInput(uint256 minTokens, uint256 deadline)
        public
        payable
        returns (uint256)
    {
        return
            ethToTokenInput(
                msg.value,
                minTokens,
                deadline,
                msg.sender,
                msg.sender
            );
    }

    /** @dev Convert ETH to tokens and transfer to recipient */
    function ethToTokenTransferInput(
        uint256 minTokens,
        uint256 deadline,
        address recipient
    ) public payable returns (uint256) {
        require(recipient != msg.sender, "Recipient cannot be self");
        require(recipient != address(0), "Recipient cannot have zero address");
        return
            ethToTokenInput(
                msg.value,
                minTokens,
                deadline,
                msg.sender,
                recipient
            );
    }

    function ethToTokenOutput(uint tokensBought, uint maxEth, uint deadline, address buyer, address recipient) private returns(uint) {
        require(deadline > block.timestamp, "The timelimit has passed");
        require(maxEth > 0, "Invalid value for ETH amount");
        require(tokensBought > 0, "Amount of tokens must be greater than 0");

        uint tokenReserve = getReserve();
        uint ethSold = getOutputPrice(tokensBought, balances[address(this)] - maxEth, tokenReserve);

        // Refund if ethSold > maxEth (in wei)
        uint ethRefund = maxEth - ethSold;
        if (ethRefund > 0) {
            payable(buyer).transfer(ethRefund); 
        }

        transferTokens(address(this), recipient, tokensBought);

        emit TokenPurchase(buyer, ethSold, tokensBought);

        return ethSold; //TODO: double check this is in wei
    }

    /** @dev Convert ETH to tokens */
    function ethToTokenSwapOutput(uint tokensBought, uint deadline) public payable returns (uint) {
        return ethToTokenOutput(tokensBought, msg.value, deadline, msg.sender, msg.sender);
    }

    /** @dev Convert ETH to tokens and transfer to recipient */
    function ethToTokenTransferOutput(uint tokensBought, uint deadline, address recipient) public payable returns (uint) {
        require(recipient != msg.sender, "Recipient cannot be self");
        require(recipient != address(0), "Recipient cannot have zero address");
        return ethToTokenOutput(tokensBought, msg.value, deadline, msg.sender, recipient);
    }

    function tokenToEthInput(uint tokensSold, uint minEth, uint deadline, address buyer, address recipient) private returns(uint) {
        require(deadline > block.timestamp, "The timelimit has passed");
        require(minEth > 0, "Invalid value for ETH amount");
        require(tokensSold > 0, "Amount of tokens must be greater than 0");

        uint tokenReserve = getReserve();
        uint ethBought = getInputPrice(tokensSold, tokenReserve, balances[address(this)]);
        uint weiBought = toWei(ethBought); // TODO
        require(weiBought >= minEth, "ETH bought must be greater than minimum");
        payable(recipient).transfer(weiBought);

        transferTokens(buyer, address(this), tokensSold);

        emit EthPurchase(buyer, tokensSold, weiBought);

        return weiBought;
    }
    
    /** @dev Convert ETH to tokens */
    function tokenToEthSwapInput(uint tokensSold, uint minEth, uint deadline) public returns (uint) {
        return tokenToEthInput(tokensSold, minEth, deadline, msg.sender, msg.sender);
    }

    /** @dev Convert ETH to tokens and transfer ETH */
    function tokenToEthTransferInput(uint tokensSold, uint minEth, uint deadline, address recipient) public returns (uint) {
        require(recipient != msg.sender, "Recipient cannot be self");
        require(recipient != address(0), "Recipient cannot have zero address");

        return tokenToEthInput(tokensSold, minEth, deadline, msg.sender, recipient);
    }

    function tokenToEthOutput(uint ethBought, uint maxTokens, uint deadline, address buyer, address recipient) private returns (uint) {
        require(deadline > block.timestamp, "The timelimit has passed");
        require(ethBought > 0, "Invalid value for ETH bought");

        uint tokenReserve = getReserve();

        uint tokensSold = getOutputPrice(ethBought, tokenReserve, balances[(address(this))]);

        require(maxTokens >= tokensSold);

        payable(recipient).send(ethBought); //TODO: use send or transfer? (check out other instances in code)

        transferTokens(buyer, address(this), tokensSold);

        emit EthPurchase(buyer, tokensSold, ethBought);

        return tokensSold;
    }

    /** @dev Convert tokens to ETH */
    function tokenToEthSwapOutput(uint ethBought, uint maxTokens, uint deadline) public returns (uint) {
        return tokenToEthOutput(ethBought, maxTokens, deadline, msg.sender, msg.sender);
    }

    /** @dev Convert tokens to ETH and transfer ETH  */
    function tokenToEthTransferOutput(uint ethBought, uint maxTokens, uint deadline, address recipient) public returns (uint) {
        require(recipient != msg.sender, "Recipient cannot be self");
        require(recipient != address(0), "Recipient cannot have zero address");
    
        return tokenToEthOutput(ethBought, maxTokens, deadline, msg.sender, recipient);
    }

    function tokenToTokenInput(uint tokensSold, uint minTokensBought, uint minEthBought, uint deadline, address buyer, address recipient, address exchange) private returns (uint) {
        require(deadline > block.timestamp, "The timelimit has passed");
        require(tokensSold > 0, "Tokens sold must be greater than 0");
        require(minTokensBought > 0, "Tokens bought must be greater than 0");
        require(minEthBought > 0, "Invalid value for ETH bought");
        require(exchange != msg.sender, "Exchange Address cannot be self");
        require(exchange != address(0), "Exchange cannot have zero address");

        uint tokenReserve = getReserve();
        uint ethBought = getInputPrice(tokensSold, tokenReserve, balances[address(this)]);

        uint weiBought = ethBought *(10**18);
        require(weiBought >= minEthBought, "The minimum ETH not met");

        transferTokens(buyer, address(this), tokensSold);
        uint tokensBought = Exchange(exchange).ethToTokenTransferInput{value: weiBought}(minTokensBought, deadline, recipient); 

        emit EthPurchase(buyer, tokensSold, weiBought);

        return tokensBought;
    }

    /** @dev Swap token (self) to token (address) 
    * This is not really going to work because factory is not implemented */
    function tokenToTokenSwapInput(uint tokensSold, uint minTokensBought, uint minEthBought, uint deadline, address _tokenAddress) public returns (uint) {
        // TODO: get address exchangeAddress from factory
        address exchangeAddress;
        return tokenToTokenInput(tokensSold, minTokensBought, minEthBought, deadline, msg.sender, msg.sender, exchangeAddress);
    }

    /** @dev Swap token (self) to token (address) and transfer tokens (address) to recipient
    * This is not really going to work because factory is not implemented */
    function tokenToTokenTransferInput(uint tokensSold, uint minTokensBought, uint minEthBought, uint deadline, address recipient, address _tokenAddress) public returns (uint) {
        // TODO: get address exchangeAddress from factory with _tokenAddress
        address exchangeAddress;
        return tokenToTokenInput(tokensSold, minTokensBought, minEthBought, deadline, msg.sender, recipient, exchangeAddress);
    }

    function tokenToTokenOutput(uint tokensBought, uint maxTokensSold, uint maxEthSold, uint deadline, address buyer, address recipient, address exchange) private returns (uint) {
        require(deadline > block.timestamp, "The timelimit has passed");
        require(tokensBought > 0, "Tokens bought must be greater than 0");
        require(maxEthSold > 0, "ETH sold must be greater than 0");

        require(exchange != msg.sender, "Exchange Address cannot be self");
        require(exchange != address(0), "Exchange cannot have zero address");

        uint ethBought = Exchange(exchange).getEthToTokenOutputPrice(tokensBought);
        
        uint tokenReserve = getReserve();

        // tokensSold > 0
        uint tokensSold = getOutputPrice(ethBought, tokenReserve, balances[address(this)]);

        require(maxTokensSold >= tokensSold, "Tokens sold is always greater than 0");
        require(maxEthSold >= ethBought, "ETH sold needs to be greater than or equal to amount bought");
        
        transferTokens(buyer, address(this), tokensSold);
        
        uint ethSold = Exchange(address).ethToTokenTransferOutput{value: ethBought}(tokensBought, deadline, recipient);

        emit EthPurchase(buyer, tokensSold, ethBought);

        return tokensSold;
    }
    
    /** @dev Swap token (self) to token (address) 
    * This is not really going to work because factory is not implemented */
    function tokenToTokenSwapOutput(uint tokensBought, uint maxTokensSold, uint maxEthSold, uint deadline, address _tokenAddress) public returns (uint) {
        // TODO: get address exchangeAddress from factory
        address exchangeAddress;
        return tokenToTokenOutput(tokensBought, maxTokensSold, maxEthSold, deadline, msg.sender, msg.sender, exchangeAddress);
    }

    /** @dev Swap token (self) to token (address) and transfer to recipient
    * This is not really going to work because factory is not implemented */
    function tokenToTokenTransferOutput() public {}

    
    /** @dev Swap token (self) to token (address) with other deployed contracts */
    function tokenToExchangeSwapInput(uint tokensSold, uint minTokensBought, uint minEthBought, uint deadline, address exchangeAddress) public returns (uint) {
        return tokenToTokenInput(tokensSold, minTokensBought, minEthBought, deadline, msg.sender, msg.sender, exchangeAddress);
    }

    /** @dev Swap token (self) to token (address) with other deployed contracts 
    *   And transfer tokens (address) to recipient */
    function tokenToExchangeTransferInput(uint tokensSold, uint minTokensBought, uint minEthBought, uint deadline, address recipient, address exchangeAddress) public returns (uint) {
        require(recipient != msg.sender, "Recipient cannot be self");
        return tokenToTokenInput(tokensSold, minTokensBought, minEthBought, deadline, msg.sender, recipient, exchangeAddress);
    }

    /** @dev Swap token (self) to token (address) with other deployed contracts */
    function tokenToExchangeSwapOutput(uint tokensBought, uint maxTokensSold, uint maxEthSold, uint deadline, address exchangeAddress) public returns (uint) {
        return tokenToTokenOutput(tokensBought, maxTokensSold, maxEthSold, deadline, msg.sender, msg.sender, exchangeAddress);
    }

    /** @dev Swap token (self) to token (address) with other deployed contracts 
    *   And transfer tokens (address) to recipient */
    function tokenToExchangeTransferOutput(uint tokensBought, uint maxTokensSold, uint maxEthSold, uint deadline, address recipient, address exchangeAddress) public returns (uint){
        require(recipient != msg.sender, "Recipient cannot be self");
        return tokenToTokenOutput(tokensBought, maxTokensSold, maxEthSold, deadline, msg.sender, recipient, exchangeAddress);
    }

    /** @dev Price function for ETH to Token with exact input because Uniswap can act as a price oracle
    *   @return amount of tokens that can be bought with input ETH */
    function getEthToTokenInputPrice(uint ethSold) public returns (uint) {
        require(ethSold > 0, "ETH sold must be greater than 0");
        
        uint tokenReserve = getReserve();

        return getInputPrice(ethSold, balances[address(this)], tokenReserve);
    }

    /** @dev Price function for ETH to Token trades with exact output 
    *   @return amount of ETH needed to buy output Tokens */
    function getEthToTokenOutputPrice(uint tokensBought) public returns (uint) {
        require(tokensBought > 0, "Tokens bought must be greater than 0");

        uint tokenReserve = getReserve();
        uint ethSold = getOutputPrice(tokensBought, balances[address(this)], tokenReserve);

        return ethSold;
    }

    /** @dev Price function for token to ETH trades with exact input 
    *   @return amount of ETH that can be bought with input tokens */
    function getTokenToEthInputPrice(uint tokensSold) public returns (uint) {
        require(tokensSold > 0, "Tokens sold must be greater than 0");

        uint tokenReserve = getReserve();

        uint ethBought = getInputPrice(tokensSold, tokenReserve, balances[address(this)]);
        return ethBought; // TODO: double check in wei
    }

    /** @dev Price function for token to ETH trades with exact output 
    *   @return amount of tokens needed to buy output ETH */
    function getTokenToEthOutputPrice(uint ethBought) public returns (uint) {
        require(ethBought > 0, "ETH bought must be greater than 0");
    
        uint tokenReserve = getReserve();

        return getOutputPrice(ethBought, tokenReserve, balances[address(this)]);
    }
}
