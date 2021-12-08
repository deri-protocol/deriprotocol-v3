// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import '../utils/NameVersion.sol';

contract TestOracle is NameVersion {

    string public symbol;

    bytes32 public symbolId;

    uint256 public value;

    constructor (string memory symbol_) NameVersion('Oracle', '3.0.1') {
        symbol = symbol_;
        symbolId = keccak256(abi.encodePacked(symbol_));
    }

    function getValue() external view returns (uint256) {
        return value;
    }

    function setValue(uint256 newValue) external {
        value = newValue;
    }

}
