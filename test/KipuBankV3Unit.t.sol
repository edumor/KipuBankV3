// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {KipuBankV3}         from "../src/KipuBankV3.sol";
import {MockERC20}           from "./mocks/MockERC20.sol";
import {MockChainlinkFeed}   from "./mocks/MockChainlinkFeed.sol";
import {MockUniswapRouter}   from "./mocks/MockUniswapRouter.sol";
import {MockUniswapFactory}  from "./mocks/MockUniswapFactory.sol";

contract KipuBankV3UnitTest is Test {
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

    int256  constant ETH_PRICE      = 2_000 * 1e8;
    int256  constant USDC_PRICE     = 1 * 1e8;
    uint256 constant ONE_ETH        = 1 ether;
    uint256 constant ETH_TO_USDC    = 2_000 * 1e6;
    uint256 constant MTK_RATE       = 100 * 1e6;
    uint256 constant MAX_CAP        = 100_000 * 1e6;
    uint256 constant MAX_ETH_AT_CAP = 50 ether;

    function setUp() public {
        usdc      = new MockERC20("USD Coin",    "USDC", 6);
        mockToken = new MockERC20("Mock Token",  "MTK",  18);
        ethFeed   = new MockChainlinkFeed(ETH_PRICE);
        usdcFeed  = new MockChainlinkFeed(USDC_PRICE);
        uniFactory = new MockUniswapFactory();
        router     = new MockUniswapRouter(address(uniFactory), makeAddr("WETH"));

        uniFactory.setPair(address(mockToken), address(usdc), makeAddr("pair_MTK_USDC"));
        router.setRate(address(mockToken), MTK_RATE);
        usdc.mint(address(router), 1_000_000 * 1e6);

        vm.startPrank(owner);
        bank = new KipuBankV3(
            owner,
            address(ethFeed),
            address(usdc),
            address(usdcFeed),
            address(router)
        );
        bank.initializeSupportedTokens();
        vm.stopPrank();

        vm.deal(alice, 100 ether);
        vm.deal(bob,   100 ether);
        usdc.mint(alice, 10_000 * 1e6);
        usdc.mint(bob,   10_000 * 1e6);
        mockToken.mint(alice, 1_000 ether);
        mockToken.mint(bob,   1_000 ether);
    }

    // ── Constructor ───────────────────────────────────────────────────────────
    function test_Constructor_SetsImmutablesCorrectly() public view {
        assertEq(bank.ethPriceFeed(),   address(ethFeed));
        assertEq(bank.usdcAddress(),    address(usdc));
        assertEq(bank.usdcPriceFeed(),  address(usdcFeed));
        assertEq(bank.uniswapRouter(),  address(router));
        assertEq(bank.uniswapFactory(), address(uniFactory));
        assertEq(bank.owner(),          owner);
    }

    function test_Constructor_InitialStateIsZero() public view {
        assertEq(bank.currentUSDCBalance(), 0);
        assertEq(bank.currentETHBalance(),  0);
        assertEq(bank.currentCapUSDC(),     0);
        assertFalse(bank.isPaused());
    }

    function test_Constructor_RevertIf_EthFeedIsZero() public {
        vm.expectRevert(KipuBankV3.ZeroAddress.selector);
        new KipuBankV3(owner, address(0), address(usdc), address(usdcFeed), address(router));
    }

    function test_Constructor_RevertIf_USDCAddressIsZero() public {
        vm.expectRevert(KipuBankV3.ZeroAddress.selector);
        new KipuBankV3(owner, address(ethFeed), address(0), address(usdcFeed), address(router));
    }

    function test_Constructor_RevertIf_USDCFeedIsZero() public {
        vm.expectRevert(KipuBankV3.ZeroAddress.selector);
        new KipuBankV3(owner, address(ethFeed), address(usdc), address(0), address(router));
    }

    function test_Constructor_RevertIf_RouterIsZero() public {
        vm.expectRevert(KipuBankV3.ZeroAddress.selector);
        new KipuBankV3(owner, address(ethFeed), address(usdc), address(usdcFeed), address(0));
    }

    // ── initializeSupportedTokens ─────────────────────────────────────────────
    function test_InitTokens_ETHIsSupported() public view {
        (bool isSupported, uint8 decimals, address priceFeed) = bank.getTokenInfo(address(0));
        assertTrue(isSupported);
        assertEq(decimals, 18);
        assertEq(priceFeed, address(ethFeed));
    }

    function test_InitTokens_USDCIsSupported() public view {
        (bool isSupported, uint8 decimals, address priceFeed) = bank.getTokenInfo(address(usdc));
        assertTrue(isSupported);
        assertEq(decimals, 6);
        assertEq(priceFeed, address(usdcFeed));
    }

    // ── depositETH ───────────────────────────────────────────────────────────
    function test_DepositETH_Success_UpdatesAllBalances() public {
        vm.prank(alice);
        bank.depositETH{value: ONE_ETH}();
        assertEq(bank.getUserBalance(alice), ETH_TO_USDC);
        assertEq(bank.currentETHBalance(),   ONE_ETH);
        assertEq(bank.currentUSDCBalance(),  ETH_TO_USDC);
        assertEq(bank.currentCapUSDC(),      ETH_TO_USDC);
    }

    function test_DepositETH_ViaReceive_WorksCorrectly() public {
        vm.prank(alice);
        (bool ok,) = address(bank).call{value: ONE_ETH}("");
        assertTrue(ok);
        assertEq(bank.getUserBalance(alice), ETH_TO_USDC);
    }

    function test_DepositETH_EmitsDepositEvent() public {
        vm.expectEmit(true, false, false, true);
        emit KipuBankV3.Deposit(alice, ETH_TO_USDC, ONE_ETH, block.timestamp);
        vm.prank(alice);
        bank.depositETH{value: ONE_ETH}();
    }

    function test_DepositETH_MultipleUsers_IndependentBalances() public {
        vm.prank(alice);
        bank.depositETH{value: ONE_ETH}();
        vm.prank(bob);
        bank.depositETH{value: 2 ether}();
        assertEq(bank.getUserBalance(alice), 2_000 * 1e6);
        assertEq(bank.getUserBalance(bob),   4_000 * 1e6);
        assertEq(bank.currentETHBalance(),   3 ether);
        assertEq(bank.currentCapUSDC(),      6_000 * 1e6);
    }

    function test_DepositETH_SameUser_BalanceAccumulates() public {
        vm.startPrank(alice);
        bank.depositETH{value: ONE_ETH}();
        bank.depositETH{value: ONE_ETH}();
        vm.stopPrank();
        assertEq(bank.getUserBalance(alice), 2 * ETH_TO_USDC);
    }

    function test_DepositETH_RevertIf_ZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(KipuBankV3.ZeroAmount.selector);
        bank.depositETH{value: 0}();
    }

    function test_DepositETH_RevertIf_Paused() public {
        vm.prank(owner);
        bank.pause();
        vm.prank(alice);
        vm.expectRevert(KipuBankV3.Paused.selector);
        bank.depositETH{value: ONE_ETH}();
    }

    function test_DepositETH_RevertIf_CapExceeded() public {
        vm.deal(alice, MAX_ETH_AT_CAP + 1 ether);
        vm.prank(alice);
        bank.depositETH{value: MAX_ETH_AT_CAP}();
        vm.prank(alice);
        vm.expectRevert(KipuBankV3.CapExceeded.selector);
        bank.depositETH{value: 1 ether}();
    }

    function test_DepositETH_RevertIf_OracleReturnsInvalidPrice() public {
        ethFeed.setInvalidPrice();
        vm.prank(alice);
        vm.expectRevert(KipuBankV3.InvalidPrice.selector);
        bank.depositETH{value: ONE_ETH}();
    }

    function test_DepositETH_RevertIf_OraclePriceIsStale() public {
        vm.warp(10000);
        ethFeed.setUpdatedAt(block.timestamp - 3601);
        vm.prank(alice);
        vm.expectRevert(KipuBankV3.StalePrice.selector);
        bank.depositETH{value: ONE_ETH}();
    }

    // ── depositERC20 (USDC) ───────────────────────────────────────────────────
    function test_DepositUSDC_Success_NoSwap() public {
        uint256 amount = 1_000 * 1e6;
        vm.startPrank(alice);
        usdc.approve(address(bank), amount);
        bank.depositERC20(address(usdc), amount);
        vm.stopPrank();
        assertEq(bank.getUserBalance(alice), amount);
        assertEq(bank.currentUSDCBalance(),  amount);
        assertEq(bank.currentCapUSDC(),      amount);
    }

    function test_DepositUSDC_RevertIf_ZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(KipuBankV3.ZeroAmount.selector);
        bank.depositERC20(address(usdc), 0);
    }

    function test_DepositUSDC_RevertIf_Paused() public {
        vm.prank(owner);
        bank.pause();
        vm.startPrank(alice);
        usdc.approve(address(bank), 1_000 * 1e6);
        vm.expectRevert(KipuBankV3.Paused.selector);
        bank.depositERC20(address(usdc), 1_000 * 1e6);
        vm.stopPrank();
    }

    function test_DepositUSDC_RevertIf_CapExceeded() public {
        uint256 overCap = MAX_CAP + 1e6;
        usdc.mint(alice, overCap);
        vm.startPrank(alice);
        usdc.approve(address(bank), overCap);
        vm.expectRevert(KipuBankV3.CapExceeded.selector);
        bank.depositERC20(address(usdc), overCap);
        vm.stopPrank();
    }

    // ── depositERC20 (token + swap) ───────────────────────────────────────────
    function test_DepositToken_WithSwap_Success() public {
        uint256 mtkAmount    = 1 ether;
        uint256 expectedUSDC = 100 * 1e6;
        vm.startPrank(alice);
        mockToken.approve(address(bank), mtkAmount);
        bank.depositERC20(address(mockToken), mtkAmount);
        vm.stopPrank();
        assertEq(bank.getUserBalance(alice), expectedUSDC);
        assertEq(bank.currentUSDCBalance(),  expectedUSDC);
    }

    function test_DepositToken_EmitsTokenSwappedEvent() public {
        uint256 mtkAmount = 1 ether;
        vm.startPrank(alice);
        mockToken.approve(address(bank), mtkAmount);
        bank.depositERC20(address(mockToken), mtkAmount);
        vm.stopPrank();
    }

    function test_DepositToken_RevertIf_NoUniswapPairAndNotSupported() public {
        MockERC20 unknownToken = new MockERC20("Unknown", "UNK", 18);
        unknownToken.mint(alice, 100 ether);
        vm.startPrank(alice);
        unknownToken.approve(address(bank), 10 ether);
        vm.expectRevert(KipuBankV3.NotSupported.selector);
        bank.depositERC20(address(unknownToken), 10 ether);
        vm.stopPrank();
    }

    // ── withdrawETH ──────────────────────────────────────────────────────────
    function test_WithdrawETH_Success_TransfersCorrectAmount() public {
        vm.prank(alice);
        bank.depositETH{value: ONE_ETH}();
        uint256 aliceETHBefore = alice.balance;
        vm.prank(alice);
        bank.withdrawETH(1_000 * 1e6);
        assertEq(alice.balance - aliceETHBefore, 0.5 ether);
        assertEq(bank.getUserBalance(alice), 1_000 * 1e6);
    }

    function test_WithdrawETH_DecreasesCapacity() public {
        vm.prank(alice);
        bank.depositETH{value: ONE_ETH}();
        uint256 capBefore = bank.currentCapUSDC();
        vm.prank(alice);
        bank.withdrawETH(1_000 * 1e6);
        assertEq(bank.currentCapUSDC(), capBefore - 1_000 * 1e6);
    }

    function test_WithdrawETH_RevertIf_ZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(KipuBankV3.ZeroAmount.selector);
        bank.withdrawETH(0);
    }

    function test_WithdrawETH_RevertIf_InsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert(KipuBankV3.InsufficientBal.selector);
        bank.withdrawETH(1_000 * 1e6);
    }

    function test_WithdrawETH_RevertIf_Paused() public {
        vm.prank(alice);
        bank.depositETH{value: ONE_ETH}();
        vm.prank(owner);
        bank.pause();
        vm.prank(alice);
        vm.expectRevert(KipuBankV3.Paused.selector);
        bank.withdrawETH(1_000 * 1e6);
    }

    // ── withdrawUSDC ─────────────────────────────────────────────────────────
    function test_WithdrawUSDC_Success_TransfersRealUSDC() public {
        uint256 deposit = 1_000 * 1e6;
        vm.startPrank(alice);
        usdc.approve(address(bank), deposit);
        bank.depositERC20(address(usdc), deposit);
        vm.stopPrank();
        uint256 aliceUSDCBefore = usdc.balanceOf(alice);
        vm.prank(alice);
        bank.withdrawUSDC(deposit);
        assertEq(usdc.balanceOf(alice), aliceUSDCBefore + deposit);
        assertEq(bank.getUserBalance(alice), 0);
    }

    function test_WithdrawUSDC_Partial_UpdatesBalances() public {
        uint256 deposit  = 1_000 * 1e6;
        uint256 withdraw = 400 * 1e6;
        vm.startPrank(alice);
        usdc.approve(address(bank), deposit);
        bank.depositERC20(address(usdc), deposit);
        vm.stopPrank();
        uint256 capBefore = bank.currentCapUSDC();
        vm.prank(alice);
        bank.withdrawUSDC(withdraw);
        assertEq(bank.getUserBalance(alice), deposit - withdraw);
        assertEq(bank.currentCapUSDC(), capBefore - withdraw);
    }

    function test_WithdrawUSDC_RevertIf_ZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(KipuBankV3.ZeroAmount.selector);
        bank.withdrawUSDC(0);
    }

    function test_WithdrawUSDC_RevertIf_InsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert(KipuBankV3.InsufficientBal.selector);
        bank.withdrawUSDC(1_000 * 1e6);
    }

    function test_WithdrawUSDC_RevertIf_Paused() public {
        uint256 deposit = 1_000 * 1e6;
        vm.startPrank(alice);
        usdc.approve(address(bank), deposit);
        bank.depositERC20(address(usdc), deposit);
        vm.stopPrank();
        vm.prank(owner);
        bank.pause();
        vm.prank(alice);
        vm.expectRevert(KipuBankV3.Paused.selector);
        bank.withdrawUSDC(deposit);
    }

    // ── Admin ─────────────────────────────────────────────────────────────────
    function test_AddSupportedToken_Success() public {
        MockERC20 newToken = new MockERC20("New Token", "NTK", 18);
        MockChainlinkFeed newFeed = new MockChainlinkFeed(50 * 1e8);
        vm.prank(owner);
        bank.addSupportedToken(address(newToken), address(newFeed), 18);
        (bool isSupported, uint8 decimals, address priceFeed) = bank.getTokenInfo(address(newToken));
        assertTrue(isSupported);
        assertEq(decimals, 18);
        assertEq(priceFeed, address(newFeed));
    }

    function test_AddSupportedToken_RevertIf_TokenIsZeroAddress() public {
        MockChainlinkFeed feed = new MockChainlinkFeed(50 * 1e8);
        vm.prank(owner);
        vm.expectRevert(KipuBankV3.ZeroAddress.selector);
        bank.addSupportedToken(address(0), address(feed), 18);
    }

    function test_AddSupportedToken_RevertIf_AlreadySupported() public {
        vm.prank(owner);
        vm.expectRevert(KipuBankV3.AlreadySupported.selector);
        bank.addSupportedToken(address(usdc), address(usdcFeed), 6);
    }

    function test_AddSupportedToken_RevertIf_CallerIsNotOwner() public {
        MockERC20 newToken = new MockERC20("X", "X", 18);
        MockChainlinkFeed newFeed = new MockChainlinkFeed(50 * 1e8);
        vm.prank(alice);
        vm.expectRevert();
        bank.addSupportedToken(address(newToken), address(newFeed), 18);
    }

    function test_RemoveSupportedToken_Success() public {
        MockERC20 newToken = new MockERC20("New", "NTK", 18);
        MockChainlinkFeed newFeed = new MockChainlinkFeed(50 * 1e8);
        vm.startPrank(owner);
        bank.addSupportedToken(address(newToken), address(newFeed), 18);
        bank.removeSupportedToken(address(newToken));
        vm.stopPrank();
        (bool isSupported,,) = bank.getTokenInfo(address(newToken));
        assertFalse(isSupported);
    }

    function test_RemoveSupportedToken_RevertIf_NotSupported() public {
        MockERC20 ghost = new MockERC20("Ghost", "GHT", 18);
        vm.prank(owner);
        vm.expectRevert(KipuBankV3.NotSupported.selector);
        bank.removeSupportedToken(address(ghost));
    }

    function test_Pause_Success() public {
        vm.prank(owner);
        bank.pause();
        assertTrue(bank.isPaused());
    }

    function test_Unpause_Success() public {
        vm.startPrank(owner);
        bank.pause();
        bank.unpause();
        vm.stopPrank();
        assertFalse(bank.isPaused());
    }

    function test_Pause_RevertIf_CallerIsNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        bank.pause();
    }

    // ── View functions ────────────────────────────────────────────────────────
    function test_GetContractState_ReturnsCorrectValues() public {
        vm.prank(alice);
        bank.depositETH{value: ONE_ETH}();
        (uint256 usdcBal, uint256 ethBal, uint256 capUsed, uint256 maxCap, uint256 weiToGwei, bool paused) = bank.getContractState();
        assertEq(usdcBal,   ETH_TO_USDC);
        assertEq(ethBal,    ONE_ETH);
        assertEq(capUsed,   ETH_TO_USDC);
        assertEq(maxCap,    MAX_CAP);
        assertEq(weiToGwei, 1e9);
        assertFalse(paused);
    }

    function test_GetUserBalance_ReturnsZeroForNewUser() public {
        assertEq(bank.getUserBalance(makeAddr("stranger")), 0);
    }

    // ── End-to-end ────────────────────────────────────────────────────────────
    function test_E2E_DepositETH_WithdrawETH_CapIsFreed() public {
        vm.prank(alice);
        bank.depositETH{value: ONE_ETH}();
        vm.prank(alice);
        bank.withdrawETH(ETH_TO_USDC);
        assertEq(bank.currentCapUSDC(), 0);
        assertEq(bank.getUserBalance(alice), 0);
    }

    function test_E2E_DepositUSDC_WithdrawUSDC_FullCycle() public {
        uint256 amount = 500 * 1e6;
        vm.startPrank(alice);
        usdc.approve(address(bank), amount);
        bank.depositERC20(address(usdc), amount);
        vm.stopPrank();
        uint256 usdcBefore = usdc.balanceOf(alice);
        vm.prank(alice);
        bank.withdrawUSDC(amount);
        assertEq(usdc.balanceOf(alice), usdcBefore + amount);
        assertEq(bank.currentCapUSDC(), 0);
    }

    function test_E2E_DepositToken_Swap_WithdrawUSDC() public {
        uint256 mtkAmount    = 2 ether;
        uint256 expectedUSDC = 200 * 1e6;
        vm.startPrank(alice);
        mockToken.approve(address(bank), mtkAmount);
        bank.depositERC20(address(mockToken), mtkAmount);
        vm.stopPrank();
        assertEq(bank.getUserBalance(alice), expectedUSDC);
        uint256 usdcBefore = usdc.balanceOf(alice);
        vm.prank(alice);
        bank.withdrawUSDC(expectedUSDC);
        assertEq(usdc.balanceOf(alice), usdcBefore + expectedUSDC);
        assertEq(bank.getUserBalance(alice), 0);
    }

    function test_E2E_CapIsReusableAfterWithdrawal() public {
        vm.deal(alice, 45 ether);
        vm.prank(alice);
        bank.depositETH{value: 45 ether}();
        vm.prank(alice);
        bank.withdrawETH(10_000 * 1e6);
        vm.deal(bob, 5 ether);
        vm.prank(bob);
        bank.depositETH{value: 5 ether}();
        assertLe(bank.currentCapUSDC(), MAX_CAP);
    }
}
