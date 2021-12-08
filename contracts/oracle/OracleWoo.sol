// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import './IOracle.sol';
import '../token/IERC20.sol';
import '../utils/NameVersion.sol';

contract OracleWoo is IOracle, NameVersion {

    string  public symbol;
    bytes32 public immutable symbolId;

    IWooracleV1 public immutable feed;
    uint256 public immutable baseDecimals;
    uint256 public immutable quoteDecimals;

    constructor (string memory symbol_, address feed_) NameVersion('OracleWoo', '3.0.1') {
        symbol = symbol_;
        symbolId = keccak256(abi.encodePacked(symbol_));
        feed = IWooracleV1(feed_);
        baseDecimals = IERC20(IWooracleV1(feed_)._BASE_TOKEN_()).decimals();
        quoteDecimals = IERC20(IWooracleV1(feed_)._QUOTE_TOKEN_()).decimals();
    }

    function timestamp() external pure returns (uint256) {
        revert('OracleWoo.timestamp: no timestamp');
    }

    function value() public view returns (uint256 val) {
        val = feed._I_();
        if (baseDecimals != quoteDecimals) {
            val = val * (10 ** baseDecimals) / (10 ** quoteDecimals);
        }
    }

    function getValue() external view returns (uint256 val) {
        require((val = value()) != 0, 'OracleWoo.getValue: 0');
    }

}

interface IWooracleV1 {
    function _BASE_TOKEN_() external view returns (address);
    function _QUOTE_TOKEN_() external view returns (address);
    function _I_() external view returns (uint256);
}
