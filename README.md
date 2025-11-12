# KipuBankV3 - Advanced DeFi Banking System

![Solidity](https://img.shields.io/badge/Solidity-0.8.26-blue)
![License](https://img.shields.io/badge/License-MIT-green)
![Network](https://img.shields.io/badge/Network-Sepolia-orange)

## 📋 Overview

**KipuBankV3** is an advanced DeFi banking system that extends KipuBankV2 functionality by integrating with **Uniswap V2** for automatic token swaps to USDC. The contract accepts any ERC20 token supported by Uniswap V2, automatically converts it to USDC, and credits the resulting amount to the user's balance while respecting the bank's maximum capacity.

**Author**: Eduardo Moreno  
**Academic Work**: Final Project Module 4 - 2025-S2-EDP-HENRY-M4  
**Contract Address (Sepolia)**: `0xFE5368128fa55C0B1d68C4271337B2a997d70b47`

## 🎯 Key Features

### Core Functionality (From KipuBankV2)
- ✅ **ETH Deposits**: Native Ethereum deposits with automatic USDC conversion
- ✅ **USDC Deposits**: Direct USDC storage without conversion
- ✅ **Withdrawal System**: Secure withdrawal mechanism for users
- ✅ **Owner Controls**: Administrative functions for contract management
- ✅ **Bank Cap Limit**: Maximum capacity enforcement (100 ETH equivalent)
- ✅ **Chainlink Price Feeds**: Real-time price data for accurate conversions

### New Features Added for TP4
- 🆕 **Universal Token Support**: Accept any ERC20 token with Uniswap V2 pairs
- 🆕 **Automatic Token Swaps**: Seamless integration with Uniswap V2 Router
- 🆕 **Dynamic Token Configuration**: Add/remove supported tokens dynamically
- 🆕 **Uniswap Pair Validation**: Automatic verification of token pairs existence
- 🆕 **Advanced Error Handling**: Custom errors for better debugging
- 🆕 **Gas Optimization**: Efficient storage and operations
- 🆕 **Emergency Pause**: Circuit breaker for security

## 🏗️ Technical Architecture

### Smart Contract Structure

```solidity
contract KipuBankV3 is Ownable {
    // Integration with Uniswap V2
    IUniswapV2Router02 public immutable uniswapRouter;
    IUniswapV2Factory public immutable uniswapFactory;
    
    // Chainlink Price Feeds
    address public immutable ethPriceFeed;
    address public immutable usdcPriceFeed;
    
    // Token Configuration
    mapping(address => TokenInfo) public supportedTokens;
    
    // User Balances (all in USDC)
    mapping(address => uint256) public userDepositUSDC;
}
```

### Key Integrations

1. **Uniswap V2 Router**: `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D`
2. **Chainlink ETH/USD**: `0x694AA1769357215DE4FAC081bf1f309aDC325306`
3. **Chainlink USDC/USD**: `0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E`
4. **USDC Token (Sepolia)**: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`

## 📚 Function Reference

### Core Banking Functions

#### `depositETH()` - ETH Deposits
```solidity
function depositETH() external payable
```
- **Purpose**: Deposit native ETH and convert to USDC equivalent
- **Requirements**: Amount > 0, contract not paused, within bank cap
- **Process**: ETH → Price conversion → USDC balance update

#### `depositToken(address token, uint256 amount)` - ERC20 Deposits
```solidity
function depositToken(address token, uint256 amount) external
```
- **Purpose**: Deposit any supported ERC20 token
- **New Feature**: Automatic Uniswap V2 swap to USDC if not USDC
- **Requirements**: Token must be supported, valid Uniswap pair exists
- **Process**: Token → Uniswap Swap → USDC → Balance update

#### `withdraw(uint256 amount)` - Withdrawals
```solidity
function withdraw(uint256 amount) external
```
- **Purpose**: Withdraw USDC equivalent in ETH
- **Requirements**: Sufficient balance, contract not paused
- **Process**: USDC balance → ETH conversion → Transfer

### Administrative Functions

#### `addToken(address token, uint8 decimals, address priceFeed)` - Add Token Support
```solidity
function addToken(address token, uint8 decimals, address priceFeed) external onlyOwner
```
- **New Feature**: Dynamically add new token support
- **Requirements**: Valid token address, not already supported
- **Purpose**: Expand supported token ecosystem

#### `removeToken(address token)` - Remove Token Support
```solidity
function removeToken(address token) external onlyOwner
```
- **New Feature**: Remove token from supported list
- **Purpose**: Manage token ecosystem security

#### `pause() / unpause()` - Emergency Controls
```solidity
function pause() external onlyOwner
function unpause() external onlyOwner
```
- **New Feature**: Emergency circuit breaker
- **Purpose**: Security mechanism for unusual situations

### View Functions

#### `getBankInfo()` - Bank Status
```solidity
function getBankInfo() external view returns (...)
```
- **Returns**: Current balances, capacity, limits, pause state
- **Purpose**: Complete bank status overview

#### `getTokenConfig(address token)` - Token Information
```solidity
function getTokenConfig(address token) external view returns (...)
```
- **Returns**: Token support status, decimals, price feed
- **Purpose**: Verify token configuration

#### `hasUniswapPair(address token)` - Pair Validation
```solidity
function hasUniswapPair(address token) external view returns (bool)
```
- **New Feature**: Check if token has USDC pair on Uniswap
- **Purpose**: Validate token compatibility

#### `getSwapPreview(address tokenIn, address tokenOut)` - Preview Swaps
```solidity
function getSwapPreview(address tokenIn, address tokenOut) external view returns (uint256)
```
- **New Feature**: Preview swap amounts before execution
- **Purpose**: User experience enhancement

## 🧪 Testing Guide for Instructors

### Contract Address
**Sepolia Testnet**: `0xFE5368128fa55C0B1d68C4271337B2a997d70b47`  
**Etherscan**: https://sepolia.etherscan.io/address/0xFE5368128fa55C0B1d68C4271337B2a997d70b47

### Step-by-Step Testing Instructions

#### 1. Initial Contract Verification
```javascript
// Check contract deployment
getBankInfo()
// Expected: currentUSDCBalance: 1, currentETHBalance: 1, currentCapUSDC: 1
```

#### 2. Test ETH Deposits (Core Functionality)
```javascript
// Test minimum ETH deposit
depositETH() 
// Send Value: 0.001 ETH
// Expected: Convert ETH to USDC equivalent and update balance
```

#### 3. Test Token Configuration (New Feature)
```javascript
// Check ETH configuration
getTokenConfig("0x0000000000000000000000000000000000000000")
// Expected: isSupported: true, decimals: 18

// Check USDC configuration  
getTokenConfig("0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238")
// Expected: isSupported: true, decimals: 6
```

#### 4. Test Uniswap Integration (New Feature)
```javascript
// Check USDC pair existence
hasUniswapPair("0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238")
// Expected: true

// Preview swap (if testing with other tokens)
getSwapPreview(tokenAddress, usdcAddress)
// Expected: Returns expected USDC amount
```

#### 5. Test Bank Capacity Limits
```javascript
// Check current capacity
getBankInfo()
// Verify: currentCapUSDC shows current utilization
// Maximum: 100 ETH equivalent in USDC
```

#### 6. Test User Balance
```javascript
// Check your balance
balanceOf("YOUR_WALLET_ADDRESS")
// Expected: Shows your USDC equivalent balance
```

#### 7. Test Administrative Functions (Owner Only)
```javascript
// Add new token support (only owner)
addToken(tokenAddress, decimals, priceFeedAddress)

// Remove token support (only owner)  
removeToken(tokenAddress)

// Emergency pause (only owner)
pause()
unpause()
```

### Quick Test Sequence
1. **Deploy Verification**: Call `getBankInfo()`
2. **ETH Deposit**: Send 0.001 ETH to `depositETH()`
3. **Balance Check**: Call `balanceOf(yourAddress)`
4. **Token Check**: Call `getTokenConfig(zeroAddress)` for ETH
5. **Capacity Check**: Verify bank limits with `getBankInfo()`

## 🔧 Deployment Instructions

### Prerequisites
- Solidity 0.8.26
- Sepolia ETH for gas fees
- Access to Remix IDE or Foundry/Hardhat

### Constructor Parameters (Sepolia)
```solidity
constructor(
    address initialOwner,     // Your wallet address
    address ethPriceFeed,     // 0x694AA1769357215DE4FAC081bf1f309aDC325306
    address usdcAddress,      // 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238  
    address usdcPriceFeed,    // 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E
    address uniswapRouter     // 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
)
```

### Deployment Steps
1. Compile with Solidity 0.8.26
2. Set gas limit to 5,000,000
3. Deploy with constructor parameters
4. Verify on Etherscan
5. Initialize token support with `initializeTokens()`

## 🚀 Improvements Over KipuBankV2

### Enhanced Features Added for TP4

1. **Universal Token Support**
   - **Before**: Only ETH and USDC
   - **Now**: Any ERC20 token with Uniswap V2 pairs
   - **Benefit**: Massive expansion of supported assets

2. **Automatic Swap Integration**
   - **Before**: Manual token handling
   - **Now**: Seamless Uniswap V2 integration
   - **Benefit**: True DeFi composability

3. **Dynamic Token Management**
   - **Before**: Fixed token support
   - **Now**: Add/remove tokens dynamically
   - **Benefit**: Flexible ecosystem adaptation

4. **Advanced Security**
   - **Before**: Basic protections
   - **Now**: Emergency pause, comprehensive validations
   - **Benefit**: Production-ready security

5. **Gas Optimization**
   - **Before**: Standard operations
   - **Now**: Optimized storage, efficient swaps
   - **Benefit**: Lower transaction costs

6. **Enhanced User Experience**
   - **Before**: Limited functionality
   - **Now**: Swap previews, detailed status information
   - **Benefit**: Better user interface support

## 🔒 Security Considerations

- **Reentrancy Protection**: Checks-Effects-Interactions pattern
- **Price Feed Validation**: Chainlink staleness and validity checks
- **Slippage Protection**: Built-in swap validation
- **Access Control**: Owner-only administrative functions
- **Emergency Pause**: Circuit breaker for unusual situations
- **Input Validation**: Comprehensive parameter checking

## 📈 Design Decisions & Trade-offs

### 1. USDC as Base Currency
- **Decision**: All balances stored in USDC equivalent
- **Benefit**: Simplified accounting, stable value reference
- **Trade-off**: Requires conversion for ETH withdrawals

### 2. Uniswap V2 Integration
- **Decision**: Use established V2 router
- **Benefit**: Reliable, well-tested protocol
- **Trade-off**: V2 vs V3 features (concentrated liquidity)

### 3. Immutable Core Addresses
- **Decision**: Price feeds and router as immutable
- **Benefit**: Gas optimization, security
- **Trade-off**: Requires redeployment for address changes

### 4. Dynamic Token Support
- **Decision**: Admin-controlled token addition
- **Benefit**: Flexibility for ecosystem growth
- **Trade-off**: Centralized control requirement

## 📄 License

MIT License - See LICENSE file for details

## 🤝 Contributing

This is an academic project for educational purposes. For suggestions or improvements, please open an issue.

---

**KipuBankV3** - Advanced DeFi Banking with Uniswap Integration  
*Developed by Eduardo Moreno as Final Project for Module 4 - Ethereum Development Program*