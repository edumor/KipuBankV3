// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract MockUniswapFactory {
    mapping(address => mapping(address => address)) private _pairs;

    function getPair(address tokenA, address tokenB) external view returns (address pair) {
        pair = _pairs[tokenA][tokenB];
        if (pair == address(0)) {
            pair = _pairs[tokenB][tokenA];
        }
    }

    function setPair(address tokenA, address tokenB, address pair) external {
        _pairs[tokenA][tokenB] = pair;
        _pairs[tokenB][tokenA] = pair;
    }

    function removePair(address tokenA, address tokenB) external {
        _pairs[tokenA][tokenB] = address(0);
        _pairs[tokenB][tokenA] = address(0);
    }
}
