# KipuBankV3 🏦

[![Solidity](https://img.shields.io/badge/Solidity-0.8.26-363636?logo=solidity)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C?logo=ethereum)](https://getfoundry.sh/)
[![Tests](https://img.shields.io/badge/Tests-60%20passing-brightgreen?logo=checkmarx)](./test/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Network](https://img.shields.io/badge/Network-Sepolia-purple)](https://sepolia.etherscan.io/)

A decentralized banking protocol built on Ethereum that enables secure ETH and ERC-20 token deposits with automatic USDC conversion via Uniswap V2, and real-time pricing through Chainlink oracles.

---

## ✨ Features

- **ETH Deposits** — Deposit native ETH, automatically valued in USDC via Chainlink price feeds
- **ERC-20 Deposits** — Deposit any supported token, auto-swapped to USDC via Uniswap V2
- **Direct USDC Deposits** — Deposit USDC directly with no conversion needed
- **ETH Withdrawals** — Withdraw your ETH balance back to your wallet
- **USDC Withdrawals** — Withdraw your USDC balance at any time
- **Price Oracle Integration** — Chainlink AggregatorV3 with staleness protection (1h max)
- **Slippage Protection** — 5% maximum slippage on all DEX swaps
- **Bank Capacity Limit** — Hard cap of 100,000 USDC to protect protocol solvency
- **Emergency Pause** — Owner can pause all operations instantly
- **Custom Errors** — Gas-optimized error handling throughout

---

## 🏗️ Architecture

```
KipuBankV3
├── src/
│   └── KipuBankV3.sol          # Main contract (861 lines)
├── test/
│   ├── KipuBankV3Unit.t.sol    # 50 unit tests
│   ├── KipuBankV3Fuzz.t.sol    # 10 fuzz/property tests
│   └── mocks/
│       ├── MockERC20.sol        # ERC-20 mock token
│       ├── MockChainlinkFeed.sol # Price feed mock
│       ├── MockUniswapRouter.sol # DEX router mock
│       └── MockUniswapFactory.sol # DEX factory mock
└── foundry.toml                 # Foundry configuration
```

### Contract Interactions

```
User
 │
 ├─── depositETH() ──────────────────► KipuBankV3
 │                                          │
 ├─── depositERC20(token, amount) ──────────┤
 │                                          ├──► Chainlink Oracle (ETH/USD price)
 ├─── withdrawETH(amount) ──────────────────┤
 │                                          ├──► Uniswap V2 Router (token → USDC swap)
 └─── withdrawUSDC(amount) ─────────────────┤
                                            └──► USDC Token Contract
```

---

## 🔐 Security Design

| Feature | Implementation |
|--------|----------------|
| Oracle staleness check | Rejects prices older than 1 hour |
| Price validation | Reverts on zero or negative price |
| Swap pair validation | Checks Uniswap factory for valid pairs |
| Slippage protection | 5% max slippage on all swaps |
| Capacity cap | 100,000 USDC hard limit |
| Emergency pause | Blocks all deposits/withdrawals |
| Custom errors | Gas-efficient revert messages |
| SafeERC20 | Protection against non-standard tokens |

### Custom Errors

```solidity
error ZeroAmount();       // Deposit or withdrawal amount is zero
error ZeroAddress();      // Address parameter is address(0)
error NotSupported();     // Token not in supported list
error CapExceeded();      // Would exceed 100,000 USDC bank cap
error InsufficientBal();  // User balance too low for withdrawal
error Paused();           // Contract is paused by owner
error AlreadySupported(); // Token already in supported list
error StalePrice();       // Chainlink price older than 1 hour
error InvalidPrice();     // Chainlink returned zero or negative price
error SwapFailed();       // Uniswap pair does not exist
```

---

## 🧪 Test Suite

**60 tests — 0 failures**

```
Ran 2 test suites: 60 tests passed, 0 failed, 0 skipped
```

### Unit Tests (50 tests)

| Category | Tests |
|----------|-------|
| Constructor | 5 tests |
| initializeSupportedTokens | 3 tests |
| depositETH | 7 tests |
| depositERC20 (USDC direct) | 6 tests |
| depositERC20 (token swap) | 4 tests |
| withdrawETH | 6 tests |
| withdrawUSDC | 6 tests |
| Admin: addSupportedToken | 5 tests |
| Admin: removeSupportedToken | 4 tests |
| Admin: pause/unpause | 5 tests |
| View functions | 3 tests |
| End-to-end flows | 3 tests |

### Fuzz Tests (10 tests)

| Test | Property Verified |
|------|-------------------|
| `testFuzz_CapNeverExceedsMax` | Cap always ≤ 100,000 USDC |
| `testFuzz_CapRevertsOverMax` | Deposits over cap always revert |
| `testFuzz_UserBalanceConsistency` | Balance matches deposited amount |
| `testFuzz_DepositWithdrawZero` | Full withdraw leaves zero balance |
| `testFuzz_ETHCapFormula` | ETH→USDC conversion formula correct |
| `testFuzz_WithdrawReducesCap` | Partial withdraw reduces cap correctly |
| + 4 additional invariant tests | Various protocol invariants |

---

## 🚀 Getting Started

### Prerequisites

- [Foundry](https://getfoundry.sh/) — Install with `curl -L https://foundry.paradigm.xyz | bash`

### Installation

```bash
git clone https://github.com/edumor/KipuBankV3.git
cd KipuBankV3
forge install foundry-rs/forge-std
```

### Run Tests

```bash
# Run all tests
forge test -v

# Run with gas report
forge test --gas-report

# Run only fuzz tests
forge test --match-contract KipuBankV3Fuzz -v

# Run specific test
forge test --match-test test_DepositETH_UpdatesBalance -vvv
```

### Deploy to Sepolia

```bash
# Set environment variables
export PRIVATE_KEY=your_private_key
export SEPOLIA_RPC_URL=your_rpc_url

# Deploy
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY --broadcast --verify
```

---

## 📋 Contract Interface

### Core Functions

```solidity
// Deposit native ETH (valued via Chainlink ETH/USD)
function depositETH() external payable

// Deposit ERC-20 token or USDC directly
function depositERC20(address token, uint256 amount) external

// Withdraw ETH to your wallet
function withdrawETH(uint256 amount) external

// Withdraw USDC to your wallet
function withdrawUSDC(uint256 amount) external
```

### Admin Functions (Owner Only)

```solidity
// Add a new supported ERC-20 token with its price feed
function addSupportedToken(address token, address priceFeed) external

// Remove a supported token
function removeSupportedToken(address token) external

// Initialize multiple supported tokens at once
function initializeSupportedTokens(address[] tokens, address[] feeds) external

// Pause all deposits and withdrawals
function pause() external

// Resume normal operations
function unpause() external
```

### View Functions

```solidity
function userDepositedETH(address user) external view returns (uint256)
function userDepositedUSDC(address user) external view returns (uint256)
function currentCapUSDC() external view returns (uint256)
function MAX_CAP() external view returns (uint256)        // 100,000 USDC
function supportedTokens(address token) external view returns (bool)
function paused() external view returns (bool)
```

---

## 🌐 Deployments

| Network | Address | Status |
|---------|---------|--------|
| Sepolia Testnet | *Coming soon* | 🔄 |
| Ethereum Mainnet | *Not deployed* | — |

---

## 🛠️ Tech Stack

- **Solidity 0.8.26** — Smart contract language
- **Foundry** — Testing framework (forge, cast, anvil)
- **Chainlink** — Decentralized price oracles
- **Uniswap V2** — Automated market maker for token swaps
- **OpenZeppelin SafeERC20** — Safe ERC-20 token interactions

---

## 📁 Key Design Decisions

**Why USDC as the base currency?**
All balances are tracked in USDC (6 decimals) for consistency. ETH and token deposits are converted to their USDC equivalent using Chainlink oracle prices, enabling a unified accounting system.

**Why Uniswap V2 for swaps?**
Uniswap V2 is the most battle-tested DEX protocol on Ethereum, with well-understood behavior and extensive liquidity. The contract validates pair existence before swapping to prevent failed transactions.

**Why a hard cap?**
The 100,000 USDC cap limits protocol exposure during the early stages and provides a natural circuit breaker. This can be adjusted in future versions with governance.

---

## 📄 License

MIT — see [LICENSE](./LICENSE)

---

## 👤 Author

**Eduardo Moreno**
- GitHub: [@edumor](https://github.com/edumor)
- LinkedIn: [eduardo-moreno-15813b19b](https://www.linkedin.com/in/eduardo-moreno-15813b19b)

---

*Built as part of the Henry Blockchain Development Program — Module 4 Final Project*
