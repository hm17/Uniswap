// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// @title Uniswap V1 Exchange
// @author Hazel Madolid
contract Exchange is ERC20 {
    // Address of ERC20 token sold on this exchange
    address public token;

    event AddLiquidity(
        address provider,
        uint256 ethAmount,
        uint256 tokenAmount
    );

    event RemoveLiquidity(address from, uint256 ethAmount, uint256 tokenAmount);
    event TokenPurchase(address buyer, uint256 ethSold, uint256 tokenBought);
    event EthPurchase(address buyer, uint256 tokensSold, uint256 weiBought);

    fallback() external payable {
        ethToTokenInput(msg.value, 1, block.timestamp, msg.sender, msg.sender);
    }

    receive() external payable { 
        address(this).balance + msg.value;
    }

    /**
     *   @param tokenAddress Address of ERC20 token sold on exchange
     **/
    constructor(address tokenAddress) ERC20("Uniswap-V1", "UNI-V1") {
        require(tokenAddress != address(0), "Token address is not valid.");
        token = tokenAddress;
    }

    /** @dev Get traded ERC20 balance of account */
    function getReserve(address account) private view returns (uint256) {
        return IERC20(token).balanceOf(account);
    }

    /** @dev Call traded ERC20 transferFrom, make sure Exchange is approved first */
    function transferTokensFrom(
        address from,
        address to,
        uint256 amount
    ) private {
        IERC20(token).transferFrom(from, to, amount);
    }

    /** @dev Add ETH and ERC20 tokens and receive liquidity tokens
     *   @param minLiquidity Minimum liquidity tokens (UNI) minted
     *   @param maxTokens Max amount of ERC20 tokens added
     *   @param deadline Transaction deadline
     *   @return uint The amount of UNI tokens minted
     **/
    function addLiquidity(
        uint256 minLiquidity,
        uint256 maxTokens,
        uint256 deadline
    ) public payable returns (uint256) {
        require(deadline > block.timestamp, "The timelimit has passed");
        require(maxTokens > 0, "Number of tokens invalid");
        require(msg.value > 0, "ETH not sent");

        uint256 totalLiquidity = totalSupply();

        // Existing liquidity
        if (totalLiquidity > 0) {
            require(minLiquidity > 0, "Invalid value for min liquidity");

            // Mint liquidity tokens in proportion to ETH and tokens added.
            uint256 ethReserve = address(this).balance - msg.value; 
            uint256 tokenReserve = getReserve(address(this));
            uint256 tokenAmount = msg.value * tokenReserve / ethReserve + 1;
            uint256 liquidityMinted = msg.value * totalLiquidity / ethReserve;

            require(maxTokens >= tokenAmount, "Token amount exceeds max");
            require(
                liquidityMinted >= minLiquidity,
                "The liquidity minted is less than the min"
            );
            _mint(msg.sender, minLiquidity);

            transferTokensFrom(msg.sender, address(this), tokenAmount);

            emit AddLiquidity(msg.sender, msg.value, tokenAmount);

            return liquidityMinted;
        } else {
            // New exchange
            require(msg.value >= 1000000000, "ETH amount not paid");

            uint256 tokenAmount = maxTokens;

            // Initial liqudity based off of ETH reserve
            uint256 initialLiquidity = address(this).balance;
            _mint(msg.sender, initialLiquidity);

            transferTokensFrom(msg.sender, address(this), tokenAmount);

            emit AddLiquidity(msg.sender, msg.value, tokenAmount);

            return initialLiquidity;
        }
    }

    /** @dev Burn UNI when removing liquidity
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
        require(amount > 0, "Amount must be greater than 0");
        require(deadline > block.timestamp, "The timelimit has passed");
        require(minEth > 0 && minTokens > 0); 

        uint256 totalLiquidity = totalSupply();
        require(totalLiquidity > 0, "There is no liquidity to remove");

        uint256 tokenReserve = getReserve(address(this));
        uint ethBalance = address(this).balance;
        uint256 ethAmount = amount * ethBalance / totalLiquidity;
        uint256 tokenAmount = (amount * 10**18) * tokenReserve / totalLiquidity;

        require(ethAmount >= minEth, "Minimum ETH amount not met");

        // Burn liquidity tokens
        _burn(msg.sender, amount);

        // Both ETH and tokens are returned
        payable(msg.sender).transfer(ethAmount);
        IERC20(token).transfer(msg.sender, tokenAmount);

        emit RemoveLiquidity(msg.sender, ethAmount, tokenAmount);

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
        require(
            inputReserve > 0 && outputReserve > 0,
            "Not enough in reserves"
        );

        uint256 inputAmountWithFee = inputAmount * 997; // 0.30% Fee
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
        require(
            inputReserve > 0 && outputReserve > 0,
            "Not enough in reserves"
        );
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

        uint256 tokenReserve = getReserve(address(this));
        uint256 tokensBought = getInputPrice(
            ethSold,
            address(this).balance - ethSold,
            tokenReserve
        );

        require(
            tokensBought >= minTokens,
            "Tokens bought less than amount expected"
        );

        IERC20(token).transfer(recipient, tokensBought);

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

    function ethToTokenOutput(
        uint256 tokensBought,
        uint256 maxEth,
        uint256 deadline,
        address buyer,
        address recipient
    ) private returns (uint256) {
        require(deadline > block.timestamp, "The timelimit has passed");
        require(maxEth > 0, "Invalid value for ETH amount");
        require(tokensBought > 0, "Amount of tokens must be greater than 0");

        uint256 tokenReserve = getReserve(address(this));
        uint256 ethSold = getOutputPrice(
            tokensBought,
            address(this).balance - maxEth,
            tokenReserve
        );

        if (maxEth > ethSold) {
            uint256 ethRefund = maxEth - ethSold;
            if (ethRefund > 0) {
                payable(buyer).transfer(ethRefund);
            }
        }

        IERC20(token).transfer(recipient, tokensBought);

        emit TokenPurchase(buyer, ethSold, tokensBought);

        return ethSold;
    }

    /** @dev Convert ETH to tokens */
    function ethToTokenSwapOutput(uint256 tokensBought, uint256 deadline)
        public
        payable
        returns (uint256)
    {
        return
            ethToTokenOutput(
                tokensBought,
                msg.value,
                deadline,
                msg.sender,
                msg.sender
            );
    }

    /** @dev Convert ETH to tokens and transfer to recipient */
    function ethToTokenTransferOutput(
        uint256 tokensBought,
        uint256 deadline,
        address recipient
    ) public payable returns (uint256) {
        require(recipient != msg.sender, "Recipient cannot be self");
        require(recipient != address(0), "Recipient cannot have zero address");
        return
            ethToTokenOutput(
                tokensBought,
                msg.value,
                deadline,
                msg.sender,
                recipient
            );
    }

    function tokenToEthInput(
        uint256 tokensSold,
        uint256 minEth,
        uint256 deadline,
        address buyer,
        address recipient
    ) private returns (uint256) {
        require(deadline > block.timestamp, "The timelimit has passed");
        require(minEth > 0, "Invalid value for ETH amount");
        require(tokensSold > 0, "Amount of tokens must be greater than 0");

        uint256 tokenReserve = getReserve(address(this));
        uint256 ethBought = getInputPrice(
            tokensSold,
            tokenReserve,
            address(this).balance
        );
        uint256 weiBought = ethBought;
        require(weiBought >= minEth, "ETH bought must be greater than minimum");
        payable(recipient).transfer(weiBought);

        transferTokensFrom(buyer, address(this), tokensSold);

        emit EthPurchase(buyer, tokensSold, weiBought);

        return weiBought;
    }

    /** @dev Convert tokens to ETH */
    function tokenToEthSwapInput(
        uint256 tokensSold,
        uint256 minEth,
        uint256 deadline
    ) public returns (uint256) {
        return
            tokenToEthInput(
                tokensSold,
                minEth,
                deadline,
                msg.sender,
                msg.sender
            );
    }

    /** @dev Convert tokens to ETH and transfer ETH */
    function tokenToEthTransferInput(
        uint256 tokensSold,
        uint256 minEth,
        uint256 deadline,
        address recipient
    ) public returns (uint256) {
        require(recipient != msg.sender, "Recipient cannot be self");
        require(recipient != address(0), "Recipient cannot have zero address");

        return
            tokenToEthInput(
                tokensSold,
                minEth,
                deadline,
                msg.sender,
                recipient
            );
    }

    function tokenToEthOutput(
        uint256 ethBought,
        uint256 maxTokens,
        uint256 deadline,
        address buyer,
        address recipient
    ) private returns (uint256) {
        require(deadline > block.timestamp, "The timelimit has passed");
        require(ethBought > 0, "Invalid value for ETH bought");

        uint256 tokenReserve = getReserve(address(this));

        uint256 tokensSold = getOutputPrice(
            ethBought,
            tokenReserve,
            address(this).balance
        );

        require(maxTokens >= tokensSold);

        // Send ETH to recipient
        payable(recipient).transfer(ethBought);

        transferTokensFrom(buyer, address(this), tokensSold);

        emit EthPurchase(buyer, tokensSold, ethBought);

        return tokensSold;
    }

    /** @dev Convert tokens to ETH */
    function tokenToEthSwapOutput(
        uint256 ethBought,
        uint256 maxTokens,
        uint256 deadline
    ) public returns (uint256) {
        return
            tokenToEthOutput(
                ethBought,
                maxTokens,
                deadline,
                msg.sender,
                msg.sender
            );
    }

    /** @dev Convert tokens to ETH and transfer ETH  */
    function tokenToEthTransferOutput(
        uint256 ethBought,
        uint256 maxTokens,
        uint256 deadline,
        address recipient
    ) public returns (uint256) {
        require(recipient != msg.sender, "Recipient cannot be self");
        require(recipient != address(0), "Recipient cannot have zero address");

        return
            tokenToEthOutput(
                ethBought,
                maxTokens,
                deadline,
                msg.sender,
                recipient
            );
    }

    function tokenToTokenInput(
        uint256 tokensSold,
        uint256 minTokensBought,
        uint256 minEthBought,
        uint256 deadline,
        address buyer,
        address recipient,
        address payable exchange
    ) private returns (uint256) {
        require(deadline > block.timestamp, "The timelimit has passed");
        require(tokensSold > 0, "Tokens sold must be greater than 0");
        require(minTokensBought > 0, "Tokens bought must be greater than 0");
        require(minEthBought > 0, "Invalid value for ETH bought");
        require(exchange != msg.sender, "Exchange Address cannot be self");
        require(exchange != address(0), "Exchange cannot have zero address");

        uint256 tokenReserve = getReserve(address(this));
        uint256 ethBought = getInputPrice(
            tokensSold,
            tokenReserve,
            address(this).balance
        );

        uint256 weiBought = ethBought;
        require(weiBought >= minEthBought, "The minimum ETH not met");

        transferTokensFrom(buyer, address(this), tokensSold);

        // Send message to deployed contract given exchange address
        uint256 tokensBought = Exchange(exchange).ethToTokenTransferInput{
            value: weiBought
        }(minTokensBought, deadline, recipient);

        emit EthPurchase(buyer, tokensSold, weiBought);

        return tokensBought;
    }

    function tokenToTokenOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address buyer,
        address recipient,
        address payable exchange
    ) private returns (uint256) {
        require(deadline > block.timestamp, "The timelimit has passed");
        require(tokensBought > 0, "Tokens bought must be greater than 0");
        require(maxEthSold > 0, "ETH sold must be greater than 0");

        require(exchange != msg.sender, "Exchange Address cannot be self");
        require(exchange != address(0), "Exchange cannot have zero address");

        uint256 ethBought = Exchange(exchange).getEthToTokenOutputPrice(
            tokensBought
        );

        uint256 tokenReserve = getReserve(address(this));

        // tokensSold > 0
        uint256 tokensSold = getOutputPrice(
            ethBought,
            tokenReserve,
            address(this).balance
        );

        require(
            maxTokensSold >= tokensSold,
            "Tokens sold is always greater than 0"
        );
        require(
            maxEthSold >= ethBought,
            "ETH sold needs to be greater than or equal to amount bought"
        );

        transferTokensFrom(buyer, address(this), tokensSold);

        uint256 ethSold = Exchange(exchange).ethToTokenTransferOutput{
            value: ethBought
        }(tokensBought, deadline, recipient);

        emit EthPurchase(buyer, tokensSold, ethBought);

        return tokensSold;
    }

    /** @dev Swap token (self) to token (address) with other deployed contracts */
    function tokenToExchangeSwapInput(
        uint256 tokensSold,
        uint256 minTokensBought,
        uint256 minEthBought,
        uint256 deadline,
        address payable exchangeAddress
    ) public returns (uint256) {
        return
            tokenToTokenInput(
                tokensSold,
                minTokensBought,
                minEthBought,
                deadline,
                msg.sender,
                msg.sender,
                exchangeAddress
            );
    }

    /** @dev Swap token (self) to token (address) with other deployed contracts
     *   And transfer tokens (address) to recipient */
    function tokenToExchangeTransferInput(
        uint256 tokensSold,
        uint256 minTokensBought,
        uint256 minEthBought,
        uint256 deadline,
        address recipient,
        address payable exchangeAddress
    ) public returns (uint256) {
        require(recipient != msg.sender, "Recipient cannot be self");
        return
            tokenToTokenInput(
                tokensSold,
                minTokensBought,
                minEthBought,
                deadline,
                msg.sender,
                recipient,
                exchangeAddress
            );
    }

    /** @dev Swap token (self) to token (address) with other deployed contracts */
    function tokenToExchangeSwapOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address payable exchangeAddress
    ) public returns (uint256) {
        return
            tokenToTokenOutput(
                tokensBought,
                maxTokensSold,
                maxEthSold,
                deadline,
                msg.sender,
                msg.sender,
                exchangeAddress
            );
    }

    /** @dev Swap token (self) to token (address) with other deployed contracts
     *   And transfer tokens (address) to recipient */
    function tokenToExchangeTransferOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address recipient,
        address payable exchangeAddress
    ) public returns (uint256) {
        require(recipient != msg.sender, "Recipient cannot be self");
        return
            tokenToTokenOutput(
                tokensBought,
                maxTokensSold,
                maxEthSold,
                deadline,
                msg.sender,
                recipient,
                exchangeAddress
            );
    }

    /** @dev Price function for ETH to Token with exact input because Uniswap can act as a price oracle
     *   @return amount of tokens that can be bought with input ETH */
    function getEthToTokenInputPrice(uint256 ethSold)
        public
        view
        returns (uint256)
    {
        require(ethSold > 0, "ETH sold must be greater than 0");

        uint256 tokenReserve = getReserve(address(this));

        return getInputPrice(ethSold, address(this).balance, tokenReserve);
    }

    /** @dev Price function for ETH to Token trades with exact output
     *   @return amount of ETH needed to buy output Tokens */
    function getEthToTokenOutputPrice(uint256 tokensBought)
        public
        view
        returns (uint256)
    {
        require(tokensBought > 0, "Tokens bought must be greater than 0");

        uint256 tokenReserve = getReserve(address(this));
        uint256 ethSold = getOutputPrice(
            tokensBought,
            address(this).balance,
            tokenReserve
        );

        return ethSold;
    }

    /** @dev Price function for token to ETH trades with exact input
     *   @return amount of ETH that can be bought with input tokens */
    function getTokenToEthInputPrice(uint256 tokensSold)
        public
        view
        returns (uint256)
    {
        require(tokensSold > 0, "Tokens sold must be greater than 0");

        uint256 tokenReserve = getReserve(address(this));

        uint256 ethBought = getInputPrice(
            tokensSold,
            tokenReserve,
            address(this).balance
        );
        return ethBought;
    }

    /** @dev Price function for token to ETH trades with exact output
     *   @return amount of tokens needed to buy output ETH */
    function getTokenToEthOutputPrice(uint256 ethBought)
        public
        view
        returns (uint256)
    {
        require(ethBought > 0, "ETH bought must be greater than 0");

        uint256 tokenReserve = getReserve(address(this));

        return getOutputPrice(ethBought, tokenReserve, address(this).balance);
    }
}
