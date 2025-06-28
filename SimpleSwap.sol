// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract SimpleSwap is ERC20 {
    using SafeERC20 for IERC20;

    address public token_A;
    address public token_B;

    uint public reserve_A;
    uint public reserve_B;

    event LiquidityAdded(address indexed provider, uint amountA, uint amountB, uint liquidity);
    event LiquidityRemoved(address indexed provider, uint amountA, uint amountB, uint liquidity);
    event TokensSwapped(address indexed user, address tokenIn, address tokenOut, uint amountIn, uint amountOut);


    constructor(address _tokenA, address _tokenB) ERC20("LIQUIDITY_POOL", "LQP") {
        require(_tokenA != _tokenB, "tokens equals!");
        token_A = _tokenA;
        token_B = _tokenB;
    }

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

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure returns (uint amountOut) {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "Invalid reserves or amount");

		uint numerator = amountIn * reserveOut;
		uint denominator = reserveIn + amountIn;
		amountOut = numerator / denominator;
    }
}