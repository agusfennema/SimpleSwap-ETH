// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleSwap {
    mapping(address => mapping(address => uint256)) public reserves;
    mapping(address => mapping(address => mapping(address => uint256))) public liquidity;

    // Agrega liquidez al pool
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidityMinted) {
        require(block.timestamp <= deadline, "Transaccion expirada");

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountADesired);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountBDesired);

        // Actualizar reservas
        reserves[tokenA][tokenB] += amountADesired;
        reserves[tokenB][tokenA] += amountBDesired;

        // Lógica simple de liquidez
        liquidity[tokenA][tokenB][to] += amountADesired + amountBDesired;
        liquidityMinted = amountADesired + amountBDesired;

        return (amountADesired, amountBDesired, liquidityMinted);
    }

    // Remueve liquidez del pool
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidityAmount,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB) {
        require(block.timestamp <= deadline, "Transaccion expirada");

        uint totalLiquidity = liquidity[tokenA][tokenB][msg.sender];
        require(totalLiquidity >= liquidityAmount, "No hay suficiente liquidez");

        amountA = liquidityAmount / 2;
        amountB = liquidityAmount / 2;

        require(amountA >= amountAMin && amountB >= amountBMin, "Slippage demasiado alto");

        liquidity[tokenA][tokenB][msg.sender] -= liquidityAmount;
        reserves[tokenA][tokenB] -= amountA;
        reserves[tokenB][tokenA] -= amountB;

        IERC20(tokenA).transfer(to, amountA);
        IERC20(tokenB).transfer(to, amountB);
    }

    // Intercambia tokens exactos
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        require(path.length == 2, "Solo se admite 1 salto");
        require(block.timestamp <= deadline, "Transaccion expirada");

        address tokenIn = path[0];
        address tokenOut = path[1];

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        uint reserveIn = reserves[tokenIn][tokenOut];
        uint reserveOut = reserves[tokenOut][tokenIn];
        uint amountOut = getAmountOut(amountIn, reserveIn, reserveOut);

        require(amountOut >= amountOutMin, "Slippage demasiado alto");

        reserves[tokenIn][tokenOut] += amountIn;
        reserves[tokenOut][tokenIn] -= amountOut;

        IERC20(tokenOut).transfer(to, amountOut);

        uint ;
        amounts[0] = amountIn;
        amounts[1] = amountOut;

        return amounts;

    }

    // Consulta el precio de un token en otro
    function getPrice(address tokenA, address tokenB) external view returns (uint price) {
        uint reserveA = reserves[tokenA][tokenB];
        uint reserveB = reserves[tokenB][tokenA];
        require(reserveB > 0, "Reserva insuficiente");
        return (reserveA * 1e18) / reserveB; // Devuelve precio con 18 decimales
    }

    // Calcula la cantidad de tokens a recibir según reservas
    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) public pure returns (uint amountOut) {
        require(amountIn > 0, "Entrada invalida");
        require(reserveIn > 0 && reserveOut > 0, "Reservas insuficientes");

        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn * 1000) + amountInWithFee;

        amountOut = numerator / denominator;
    }
}
