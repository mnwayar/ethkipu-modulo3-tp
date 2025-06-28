// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/// @title SimpleSwap
/// @author Wayar Matias Nahuel
/// @notice This contract allows the addition and remove of liquidity, the swap between TokenA and TokenB and returns the price. 
/// @notice Also, implements IERC20 and manage the LQP token.
contract SimpleSwap2 is ERC20 {
    using SafeERC20 for IERC20;

    // Variables

    /// @dev address of token A, setted in constructor
    address public token_A;
    /// @dev address of token B, setted in constructor
    address public token_B;
    /// @dev reserves of token A
    uint public reserve_A;
    /// @dev reserves of token B
    uint public reserve_B;

    // Events

    /// @notice Emitted when liquidity is added
    /// @param provider address of who adds liquidity
    /// @param amountA amount token A
    /// @param amountB amount token B
    /// @param liquidity liquidity generated
    event LiquidityAdded(address indexed provider, uint amountA, uint amountB, uint liquidity);

    /// @notice Emitted when liquidity is removed
    /// @param provider address of who removes liquidity
    /// @param amountA amount token A
    /// @param amountB amount token B
    /// @param liquidity liquidity burned
    event LiquidityRemoved(address indexed provider, uint amountA, uint amountB, uint liquidity);

    /// @notice Emitted when liquidity is added
    /// @param user address of who realize the swap
    /// @param tokenIn token swapped
    /// @param tokenOut token swapped to
    /// @param amountIn amount ingressed
    /// @param amountOut amount obtained
    event TokensSwapped(address indexed user, address tokenIn, address tokenOut, uint amountIn, uint amountOut);

    /// @notice Constructor that initialize the contract
    /// @dev sets the token A and token B addresses, and token and symbol for LP
    constructor(address _tokenA, address _tokenB) ERC20("LIQUIDITY_POOL", "LQP") {
        require(_tokenA != _tokenB, "tokens equals!");
        token_A = _tokenA;
        token_B = _tokenB;
    }

    /// @notice Adds liquidity and mints LQP tokens
    /// @dev emits the event {LiquidityAdded}
    /// @param tokenA address of token A
    /// @param tokenB address of token B
    /// @param amountADesired desired amount of token A
    /// @param amountBDesired desired amount of token B
    /// @param amountAMin minimum acceptable amount of token A
    /// @param amountBMin minimum acceptable amount of token B
    /// @param to address receiving liquidity tokens
    /// @param deadline timestamp to check if transaction is valid
    /// @return amountA amount of token A deposited
    /// @return amountB amount of token B deposited
    /// @return liquidity amount of LQP tokens minted
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity) {
        require(block.timestamp <= deadline, "Transaction expired");
        require((tokenA == token_A && tokenB == token_B) || (tokenA == token_B && tokenB == token_A), "Invalid token pair");
        require(to != address(0), "Invalid 'to' address");

        uint _reserve_A = reserve_A;
        uint _reserve_B = reserve_B;
        uint _totalLiquidity = totalSupply();

        if (_reserve_A == 0 && _reserve_B == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = (amountADesired * _reserve_B) / _reserve_A;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Insufficient B amount");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = (amountBDesired * _reserve_A) / _reserve_B;
                require(amountAOptimal >= amountAMin, "Insufficient A amount");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }

        if (tokenA == token_A) {
            IERC20(token_A).safeTransferFrom(msg.sender, address(this), amountA);
            IERC20(token_B).safeTransferFrom(msg.sender, address(this), amountB);
        } else {
            IERC20(token_A).safeTransferFrom(msg.sender, address(this), amountB);
            IERC20(token_B).safeTransferFrom(msg.sender, address(this), amountA);
        }

        if (_totalLiquidity == 0) {
            liquidity = Math.sqrt(amountA * amountB);
        } else {
            liquidity = Math.min((amountA * _totalLiquidity) / _reserve_A, (amountB * _totalLiquidity) / _reserve_B);
        }

        require(liquidity > 0, "Insufficient liquidity");

        reserve_A = _reserve_A + amountA;
        reserve_B = _reserve_B + amountB;
       
        _mint(to, liquidity);
        emit LiquidityAdded(to, amountA, amountB, liquidity);
        return (amountA, amountB, liquidity);
    }

    /// @notice Removes liquidity and burns LQP tokens
    /// @dev emits the event {LiquidityRemoved}
    /// @param tokenA address of token A
    /// @param tokenB address of token B
    /// @param liquidity amount of LQP tokens to be burn
    /// @param amountAMin minimum acceptable amount of token A
    /// @param amountBMin minimum acceptable amount of token B
    /// @param to address receiving the tokens
    /// @param deadline timestamp to check if transaction is valid
    /// @return amountA amount of token A returned
    /// @return amountB amount of token B returned
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB) {
        require(block.timestamp <= deadline, "Transaction expired");
        require((tokenA == token_A && tokenB == token_B) || (tokenA == token_B && tokenB == token_A), "Invalid token pair");
        require(to != address(0), "Invalid 'to' address");

        uint _reserve_A = reserve_A;
        uint _reserve_B = reserve_B;
        uint _totalLiquidity = totalSupply();

        require(balanceOf(msg.sender) >= liquidity, "Not enough liquidity");

        amountA = (liquidity * _reserve_A) / _totalLiquidity;
        amountB = (liquidity * _reserve_B) / _totalLiquidity;

        require(amountA >= amountAMin && amountB >= amountBMin, "Slippage limit");

        reserve_A = _reserve_A - amountA;
        reserve_B = _reserve_B - amountB;

        if (tokenA == token_A) {
            IERC20(token_A).safeTransfer(to, amountA);
            IERC20(token_B).safeTransfer(to, amountB);
        } else {
            IERC20(token_A).safeTransfer(to, amountB);
            IERC20(token_B).safeTransfer(to, amountA);
        }

        _burn(msg.sender, liquidity);
        emit LiquidityRemoved(to, amountA, amountB, liquidity);
        return(amountA, amountB);    
    }

    /// @notice Swaps an exact amount of input tokens for output tokens
    /// @dev emits the event {TokensSwapped}
    /// @param amountIn amount of input token to send
    /// @param amountOutMin minimum acceptable amount of output token
    /// @param path array with [tokenIn, tokenOut] addresses
    /// @param to address to receive the output token
    /// @param deadline timestamp to check if transaction is valid
    /// @return amounts array of token amounts [amountIn, amountOut]
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        require(block.timestamp <= deadline, "Transaction expired");
        require(path.length == 2, "Invalid path length");
        require(to != address(0), "Invalid 'to' address");

        address tokenIn = path[0];
        address tokenOut = path[1];
        require((tokenIn == token_A && tokenOut == token_B) || (tokenIn == token_B && tokenOut == token_A), "Invalid tokens");

        bool isTokenAIn = tokenIn == token_A;
        uint amountOut = (amountIn * (isTokenAIn ? reserve_B : reserve_A)) / ((isTokenAIn ? reserve_A : reserve_B) + amountIn);
        require(amountOut >= amountOutMin, "Insufficient output amount");

        if (isTokenAIn) {
            reserve_A += amountIn;
            reserve_B -= amountOut;
        } else {
            reserve_B += amountIn;
            reserve_A -= amountOut;
        }

        amounts = new uint[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).safeTransfer(to, amountOut);
        emit TokensSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
        return amounts;
    }

    /// @notice Returns the price of tokenA in terms of tokenB
    /// @param tokenA address
    /// @param tokenB address
    /// @return price price with 18 decimals (tokenB per tokenA)
    function getPrice(address tokenA, address tokenB) external view returns (uint price) {
        require((tokenA == token_A && tokenB == token_B) || (tokenA == token_B && tokenB == token_A), "Invalid tokens");
        require(reserve_A > 0 && reserve_B > 0, "No liquidity");

        bool isTokenAIn = tokenA == token_A;

        if (isTokenAIn) {
            price = (reserve_B * 1e18) / reserve_A;
        } else {
            price = (reserve_A * 1e18) / reserve_B;
        }

        return price;        
    }

    /// @notice returns output amount for an input and reserve
    /// @param tokenIn address input token
    /// @param tokenOut address output token
    /// @param amountIn amount of input token
    /// @return amountOut token amount to swap
    function getAmountOut(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256 amountOut) {
        require(amountIn > 0, "Invalid input amount");
        require((tokenIn == token_A && tokenOut == token_B) || (tokenIn == token_B && tokenOut == token_A), "Invalid tokens");
        
        uint reserveIn;
        uint reserveOut;

        if (tokenIn == token_A) {
            reserveIn = reserve_A;
            reserveOut = reserve_B;
        } else {
            reserveIn = reserve_B;
            reserveOut = reserve_A;
        }

        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        uint numerator = amountIn * reserveOut;
        uint denominator = reserveIn + amountIn;
        amountOut = numerator / denominator;
        return amountOut;
    }
}