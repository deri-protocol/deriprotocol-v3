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
        (uint256 updatedAt, ) = _getLatestRoundData();
        return updatedAt;
    }

    function value() public view returns (uint256 val) {
        (, int256 answer) = _getLatestRoundData();
        val = answer.itou();
        if (feedDecimals != 18) {
            val *= 10 ** (18 - feedDecimals);
        }
    }

    function getValue() external view returns (uint256 val) {
        val = value();
    }

    function _getLatestRoundData() internal view returns (uint256, int256) {
        (uint80 roundId, int256 answer, , uint256 updatedAt, uint80 answeredInRound) = feed.latestRoundData();
        require(answeredInRound >= roundId, 'OracleChainlink._getLatestRoundData: stale');
        require(updatedAt != 0, 'OracleChainlink._getLatestRoundData: incomplete round');
        require(answer > 0, 'OracleChainlink._getLatestRoundData: answer <= 0');
        return (updatedAt, answer);
    }

}

interface IChainlinkFeed {
    function decimals() external view returns (uint8);
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}
