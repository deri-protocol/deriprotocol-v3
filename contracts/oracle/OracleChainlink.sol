// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import './IOracle.sol';
import '../library/SafeMath.sol';
import '../utils/NameVersion.sol';

contract OracleChainlink is IOracle, NameVersion {

    using SafeMath for int256;

    string  public symbol;
    bytes32 public immutable symbolId;

    IChainlinkFeed public immutable feed;
    uint256 public immutable feedDecimals;

    constructor (string memory symbol_, address feed_) NameVersion('OracleChainlink', '3.0.1') {
        symbol = symbol_;
        symbolId = keccak256(abi.encodePacked(symbol_));
        feed = IChainlinkFeed(feed_);
        feedDecimals = IChainlinkFeed(feed_).decimals();
    }

    function timestamp() external view returns (uint256) {
        return feed.latestTimestamp();
    }

    function value() public view returns (uint256 val) {
        val = feed.latestAnswer().itou();
        if (feedDecimals != 18) {
            val *= 10 ** (18 - feedDecimals);
        }
    }

    function getValue() external view returns (uint256 val) {
        require((val = value()) != 0, 'OracleChainlink.getValue: 0');
    }

}

interface IChainlinkFeed {
    function decimals() external view returns (uint8);
    function latestTimestamp() external view returns (uint256);
    function latestAnswer() external view returns (int256);
}
