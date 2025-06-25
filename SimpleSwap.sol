// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Defino la interfaz IERC20 para poder interactuar con contratos de tokens que siguen el estándar ERC-20.
// Es la forma en que mi contrato puede llamar a funciones como transfer, transferFrom, approve, etc.
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// Contrato principal de intercambio simple de tokens (tipo Uniswap pero muy básico)
contract SimpleSwap {
    // Mapeo que guarda las reservas de tokens por cada par (ej: DAI/USDC)
    mapping(address => mapping(address => uint256)) public reserves;

    // Mapeo que lleva el control de cuánta liquidez tiene cada usuario en un par
    mapping(address => mapping(address => mapping(address => uint256))) public liquidity;

    // Función para agregar liquidez a un par de tokens
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

        // Transfiero los tokens desde el usuario al contrato
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountADesired);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountBDesired);

        // Actualizo las reservas internas del contrato
        reserves[tokenA][tokenB] += amountADesired;
        reserves[tokenB][tokenA] += amountBDesired;

        // Registro la liquidez agregada para el usuario
        liquidity[tokenA][tokenB][to] += amountADesired + amountBDesired;
        liquidityMinted = amountADesired + amountBDesired;

        return (amountADesired, amountBDesired, liquidityMinted);
    }

    // Función para remover liquidez que el usuario había aportado al pool
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

        // Verifico que el usuario tenga suficiente liquidez
        uint totalLiquidity = liquidity[tokenA][tokenB][msg.sender];
        require(totalLiquidity >= liquidityAmount, "No hay suficiente liquidez");

        // Divido la liquidez por igual entre los dos tokens (por simplicidad)
        amountA = liquidityAmount / 2;
        amountB = liquidityAmount / 2;

        // Reviso si el mínimo esperado por el usuario se cumple
        require(amountA >= amountAMin && amountB >= amountBMin, "Slippage demasiado alto");

        // Actualizo los datos internos del contrato
        liquidity[tokenA][tokenB][msg.sender] -= liquidityAmount;
        reserves[tokenA][tokenB] -= amountA;
        reserves[tokenB][tokenA] -= amountB;

        // Envío los tokens de vuelta al usuario
        IERC20(tokenA).transfer(to, amountA);
        IERC20(tokenB).transfer(to, amountB);
    }

    // Función principal para intercambiar tokens: envío una cantidad exacta de un token y recibo otro
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        // Solo acepto swaps de un solo salto (ej: DAI a USDC)
        require(path.length == 2, "Solo se admite 1 salto");
        require(block.timestamp <= deadline, "Transaccion expirada");

        // Guardo las direcciones de entrada y salida
        address tokenIn = path[0];
        address tokenOut = path[1];

        // Transfiero el token de entrada desde el usuario al contrato
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // Consulto las reservas para calcular cuánto token de salida puedo dar
        uint reserveIn = reserves[tokenIn][tokenOut];
        uint reserveOut = reserves[tokenOut][tokenIn];
        uint amountOut = getAmountOut(amountIn, reserveIn, reserveOut);

        // Verifico que no se haya deslizado mucho el precio
        require(amountOut >= amountOutMin, "Slippage demasiado alto");

        // Actualizo reservas
        reserves[tokenIn][tokenOut] += amountIn;
        reserves[tokenOut][tokenIn] -= amountOut;

        // Envío el token de salida al usuario
        IERC20(tokenOut).transfer(to, amountOut);

        // Devuelvo los montos intercambiados en un array
        amounts = new uint ;
        amounts[0] = amountIn;
        amounts[1] = amountOut;

        return amounts;
    }

    // Función auxiliar para consultar el precio actual de un token en otro
    function getPrice(address tokenA, address tokenB) external view returns (uint price) {
        uint reserveA = reserves[tokenA][tokenB];
        uint reserveB = reserves[tokenB][tokenA];
        require(reserveB > 0, "Reserva insuficiente");
        // Devuelvo el precio con 18 decimales de precisión
        return (reserveA * 1e18) / reserveB;
    }

    // Función auxiliar para calcular cuánto se recibe de salida según la fórmula de Uniswap (con fee del 0.3%)
    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) public pure returns (uint amountOut) {
        require(amountIn > 0, "Entrada invalida");
        require(reserveIn > 0 && reserveOut > 0, "Reservas insuficientes");

        // Aplico el fee (0.3%) y la fórmula constante de producto
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn * 1000) + amountInWithFee;

        amountOut = numerator / denominator;
    }
}

