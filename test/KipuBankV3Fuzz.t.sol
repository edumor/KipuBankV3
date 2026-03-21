// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {KipuBankV3}         from "../src/KipuBankV3.sol";
import {MockERC20}           from "./mocks/MockERC20.sol";
import {MockChainlinkFeed}   from "./mocks/MockChainlinkFeed.sol";
import {MockUniswapRouter}   from "./mocks/MockUniswapRouter.sol";
import {MockUniswapFactory}  from "./mocks/MockUniswapFactory.sol";

contract KipuBankV3FuzzTest is Test {
    KipuBankV3          internal bank;
    MockERC20           internal usdc;
    MockERC20           internal mockToken;
    MockChainlinkFeed   internal ethFeed;
    MockChainlinkFeed   internal usdcFeed;
    MockUniswapRouter   internal router;
    MockUniswapFactory  internal uniFactory;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob   = makeAddr("bob");

    int256  constant ETH_PRICE        = 2_000 * 1e8;
    uint256 constant MAX_CAP          = 100_000 * 1e6;
    uint256 constant MTK_RATE         = 100 * 1e6;
    uint256 constant MIN_ETH_DEPOSIT  = 5e8;
    uint256 constant MAX_ETH_SINGLE   = 50 ether;

    function setUp() public {
        usdc      = new MockERC20("USD Coin",   "USDC", 6);
        mockToken = new MockERC20("Mock Token", "MTK",  18);
        ethFeed   = new MockChainlinkFeed(ETH_PRICE);
        usdcFeed  = new MockChainlinkFeed(1 * 1e8);
        uniFactory = new MockUniswapFactory();
        router     = new MockUniswapRouter(address(uniFactory), makeAddr("WETH"));
        uniFactory.setPair(address(mockToken), address(usdc), makeAddr("pair"));
        router.setRate(address(mockToken), MTK_RATE);
        usdc.mint(address(router), 10_000_000 * 1e6);
        vm.startPrank(owner);
        bank = new KipuBankV3(owner, address(ethFeed), address(usdc), address(usdcFeed), address(router));
        bank.initializeSupportedTokens();
        vm.stopPrank();
    }

    function testFuzz_DepositETH_CapNeverExceedsMaxCap(uint256 amount) public {
        amount = bound(amount, MIN_ETH_DEPOSIT, MAX_ETH_SINGLE);
        vm.deal(alice, amount);
        vm.prank(alice);
        bank.depositETH{value: amount}();
        assertLe(bank.currentCapUSDC(), MAX_CAP);
    }

    function testFuzz_DepositUSDC_CapNeverExceedsMaxCap(uint256 amount) public {
        amount = bound(amount, 1, MAX_CAP);
        usdc.mint(alice, amount);
        vm.startPrank(alice);
        usdc.approve(address(bank), amount);
        bank.depositERC20(address(usdc), amount);
        vm.stopPrank();
        assertLe(bank.currentCapUSDC(), MAX_CAP);
    }

    function testFuzz_TwoDeposits_CombinedCapNeverExceedsMaxCap(uint256 amountAlice, uint256 amountBob) public {
        amountAlice = bound(amountAlice, MIN_ETH_DEPOSIT, 25 ether);
        amountBob   = bound(amountBob,   MIN_ETH_DEPOSIT, 25 ether);
        vm.deal(alice, amountAlice);
        vm.deal(bob,   amountBob);
        vm.prank(alice);
        bank.depositETH{value: amountAlice}();
        vm.prank(bob);
        bank.depositETH{value: amountBob}();
        assertLe(bank.currentCapUSDC(), MAX_CAP);
    }

    function testFuzz_UserBalance_NeverExceedsTotalCap(uint256 amount) public {
        amount = bound(amount, MIN_ETH_DEPOSIT, MAX_ETH_SINGLE);
        vm.deal(alice, amount);
        vm.prank(alice);
        bank.depositETH{value: amount}();
        assertLe(bank.getUserBalance(alice), bank.currentCapUSDC());
    }

    function testFuzz_DepositUSDC_ThenWithdrawAll_BalanceIsZero(uint256 amount) public {
        amount = bound(amount, 1, MAX_CAP);
        usdc.mint(alice, amount);
        vm.startPrank(alice);
        usdc.approve(address(bank), amount);
        bank.depositERC20(address(usdc), amount);
        bank.withdrawUSDC(amount);
        vm.stopPrank();
        assertEq(bank.getUserBalance(alice), 0);
        assertEq(bank.currentCapUSDC(),      0);
    }

    function testFuzz_DepositETH_ThenWithdrawAll_BalanceIsZero(uint256 amount) public {
        amount = bound(amount, MIN_ETH_DEPOSIT, MAX_ETH_SINGLE);
        vm.deal(alice, amount);
        vm.prank(alice);
        bank.depositETH{value: amount}();
        uint256 fullBalance = bank.getUserBalance(alice);
        vm.assume(fullBalance > 0);
        vm.prank(alice);
        bank.withdrawETH(fullBalance);
        assertEq(bank.getUserBalance(alice), 0);
    }

    function testFuzz_WithdrawUSDC_Partial_RemainingBalanceIsCorrect(uint256 deposit, uint256 withdrawFraction) public {
        deposit          = bound(deposit,          1_000 * 1e6, MAX_CAP);
        withdrawFraction = bound(withdrawFraction, 1,           99);
        usdc.mint(alice, deposit);
        vm.startPrank(alice);
        usdc.approve(address(bank), deposit);
        bank.depositERC20(address(usdc), deposit);
        vm.stopPrank();
        uint256 toWithdraw = (deposit * withdrawFraction) / 100;
        vm.assume(toWithdraw > 0);
        uint256 balanceBefore = bank.getUserBalance(alice);
        vm.prank(alice);
        bank.withdrawUSDC(toWithdraw);
        assertEq(bank.getUserBalance(alice), balanceBefore - toWithdraw);
    }

    function testFuzz_WithdrawUSDC_CapDecreasesByExactAmount(uint256 amount) public {
        usdc.mint(alice, MAX_CAP);
        vm.startPrank(alice);
        usdc.approve(address(bank), MAX_CAP);
        bank.depositERC20(address(usdc), MAX_CAP);
        vm.stopPrank();
        amount = bound(amount, 1, MAX_CAP);
        uint256 capBefore = bank.currentCapUSDC();
        vm.prank(alice);
        bank.withdrawUSDC(amount);
        assertEq(bank.currentCapUSDC(), capBefore - amount);
    }

    function testFuzz_WithdrawUSDC_MoreThanBalance_AlwaysReverts(uint256 deposit, uint256 excess) public {
        deposit = bound(deposit, 1 * 1e6, MAX_CAP);
        excess  = bound(excess,  1,       type(uint128).max);
        usdc.mint(alice, deposit);
        vm.startPrank(alice);
        usdc.approve(address(bank), deposit);
        bank.depositERC20(address(usdc), deposit);
        vm.stopPrank();
        vm.prank(alice);
        vm.expectRevert(KipuBankV3.InsufficientBal.selector);
        bank.withdrawUSDC(deposit + excess);
    }

    function testFuzz_DepositETH_USDCAmountMatchesOracleFormula(uint256 ethAmount) public {
        ethAmount = bound(ethAmount, MIN_ETH_DEPOSIT, MAX_ETH_SINGLE);
        uint256 expectedUSDC = (ethAmount * uint256(ETH_PRICE)) / 1e20;
        vm.assume(expectedUSDC > 0);
        vm.deal(alice, ethAmount);
        vm.prank(alice);
        bank.depositETH{value: ethAmount}();
        assertEq(bank.getUserBalance(alice), expectedUSDC);
    }
}
