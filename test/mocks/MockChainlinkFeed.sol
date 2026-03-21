// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract MockChainlinkFeed {
    int256  public price;
    uint256 public updatedAt;

    constructor(int256 _price) {
        price     = _price;
        updatedAt = block.timestamp;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80  roundId,
            int256  answer,
            uint256 startedAt,
            uint256 updatedAt_,
            uint80  answeredInRound
        )
    {
        return (1, price, block.timestamp, updatedAt, 1);
    }

    function setPrice(int256 _price) external {
        price     = _price;
        updatedAt = block.timestamp;
    }

    function setUpdatedAt(uint256 _updatedAt) external {
        updatedAt = _updatedAt;
    }

    function setInvalidPrice() external {
        price = -1;
    }

    function reset(int256 _price) external {
        price     = _price;
        updatedAt = block.timestamp;
    }
}
