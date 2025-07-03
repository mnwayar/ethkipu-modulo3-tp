
# SimpleSwap

A lightweight decentralized exchange smart contract for swapping between two tokens, adding/removing liquidity, and querying prices. The contract is compatible with [OpenZeppelin Contracts ^5.0.0](https://docs.openzeppelin.com/contracts).

## 🧑‍💻 Author

**Wayar Matias Nahuel**

## 📄 Description

`SimpleSwap` is a minimal Uniswap-like smart contract that allows:
- Adding and removing liquidity between two pre-defined tokens (`token_A` and `token_B`)
- Performing token swaps using a constant product formula
- Minting and burning LP tokens (`LQP`) to represent shares in the liquidity pool
- Fetching the price of one token in terms of the other

The LP token follows the ERC-20 standard and inherits from `OpenZeppelin`'s `ERC20`.

---

## ⚙️ Constructor

```solidity
constructor(address _tokenA, address _tokenB)
```

### Initializes the contract with the two token addresses and sets up the LP token (name: `LIQUIDITY_POOL`, symbol: `LQP`).

- `_tokenA`: Address of token A.
- `_tokenB`: Address of token B (must be different from token A).

---

## 🚰 addLiquidity

```solidity
function addLiquidity(
    address tokenA,
    address tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
) external returns (uint amountA, uint amountB, uint liquidity)
```

Adds liquidity to the pool and mints `LQP` tokens for the provider.

- `tokenA`, `tokenB`: Must match the tokens configured in the constructor.
- `amountADesired`, `amountBDesired`: The amounts the user wishes to provide.
- `amountAMin`, `amountBMin`: Minimum accepted amounts to avoid slippage.
- `to`: Address receiving the LP tokens.
- `deadline`: Unix timestamp after which the transaction will be rejected.

🟢 Emits: `LiquidityAdded`

---

## 💧 removeLiquidity

```solidity
function removeLiquidity(
    address tokenA,
    address tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
) external returns (uint amountA, uint amountB)
```

Removes liquidity from the pool and burns `LQP` tokens.

- `tokenA`, `tokenB`: Must match the tokens configured in the constructor.
- `liquidity`: Amount of LP tokens to burn.
- `amountAMin`, `amountBMin`: Minimum tokens expected to withdraw.
- `to`: Address to receive the tokens.
- `deadline`: Unix timestamp after which the transaction will be rejected.

🟢 Emits: `LiquidityRemoved`

---

## 🔄 swapExactTokensForTokens

```solidity
function swapExactTokensForTokens(
    uint amountIn,
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
) external returns (uint[] memory amounts)
```

Swaps a fixed amount of one token for the other using the pool's reserves.

- `amountIn`: Input amount of tokens to be swapped.
- `amountOutMin`: Minimum acceptable output amount.
- `path`: Must contain exactly two elements: `[tokenIn, tokenOut]`.
- `to`: Recipient of the output tokens.
- `deadline`: Expiration time for the transaction.

🟢 Emits: `TokensSwapped`

---

## 📈 getPrice

```solidity
function getPrice(address tokenA, address tokenB) external view returns (uint price)
```

Returns the price of `tokenA` in terms of `tokenB`, with 18 decimals precision.

- Returns `tokenB per tokenA` if `tokenA == token_A`, or the reverse if `tokenA == token_B`.

---

## 📐 getAmountOut

```solidity
function getAmountOut(
    uint amountIn,
    uint reserveIn,
    uint reserveOut
) public pure returns (uint amountOut)
```

Utility function to calculate the output amount of tokens using the constant product formula.

---

## 📦 Events

### `LiquidityAdded`

```solidity
event LiquidityAdded(address indexed provider, uint amountA, uint amountB, uint liquidity);
```

### `LiquidityRemoved`

```solidity
event LiquidityRemoved(address indexed provider, uint amountA, uint amountB, uint liquidity);
```

### `TokensSwapped`

```solidity
event TokensSwapped(address indexed user, address tokenIn, address tokenOut, uint amountIn, uint amountOut);
```

---

## 🔐 Requirements & Assumptions

- The token pair is fixed at deployment and cannot be changed.
- Only two tokens are supported (no multi-hop swaps).
- There are no trading fees or protocol fees.
- Slippage protection must be manually specified via `amountMin` parameters.

---

## Deployment

This contract was deployed to the Sepolia testnet using Remix.

- **Network**: Sepolia
- **Contract address**: `0xF3D89dbc8abBB33020B916026BE77875FF9A7028`
- **Token A address**: `0x2d2B2C2af6f4F87E722E064dcD9fDd3F94ce7597`
- **Token B address**: `0xe7318ea312EE8b8faAD947136f4C1b0d75484667`
- **LP Token Symbol**: LQP

---

## 🧪 Example Usage

```solidity
// Add liquidity
simpleSwap.addLiquidity(tokenA, tokenB, 1000, 1000, 950, 950, msg.sender, block.timestamp + 300);

// Swap tokens
simpleSwap.swapExactTokensForTokens(500, 490, [tokenA, tokenB], msg.sender, block.timestamp + 300);

// Get tokenA price in terms of tokenB
uint price = simpleSwap.getPrice(tokenA, tokenB);
```

---

## 📝 License

This project is licensed under the [MIT License](./LICENSE).
