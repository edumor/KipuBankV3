// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IERC20Min {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract MockUniswapRouter {
    address public immutable factoryAddr;
    address public immutable WETH;
    mapping(address => uint256) public usdcPer1e18;

    constructor(address _factory, address _weth) {
        factoryAddr = _factory;
        WETH        = _weth;
    }

    function factory() external view returns (address) {
        return factoryAddr;
    }

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts) {
        amounts    = new uint256[](path.length);
        amounts[0] = amountIn;
        uint256 rate = usdcPer1e18[path[0]];
        amounts[amounts.length - 1] = (amountIn * rate) / 1e18;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(deadline >= block.timestamp, "MockRouter: EXPIRED");
        uint256 amountOut = (amountIn * usdcPer1e18[path[0]]) / 1e18;
        require(amountOut >= amountOutMin, "MockRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        require(amountOut > 0, "MockRouter: ZERO_OUTPUT");
        IERC20Min(path[0]).transferFrom(msg.sender, address(this), amountIn);
        IERC20Min(path[path.length - 1]).transfer(to, amountOut);
        amounts    = new uint256[](path.length);
        amounts[0] = amountIn;
        amounts[amounts.length - 1] = amountOut;
    }

    function setRate(address token, uint256 rateUSDC) external {
        usdcPer1e18[token] = rateUSDC;
    }
}
