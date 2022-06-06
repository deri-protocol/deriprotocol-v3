// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import './IOracleOffChain.sol';
import '../utils/NameVersion.sol';

contract OracleOffChain is IOracleOffChain, NameVersion {

    string  public symbol;
    bytes32 public immutable symbolId;
    address public immutable signer;
    uint256 public immutable delayAllowance;

    uint256 public timestamp;
    uint256 public value;

    constructor (string memory symbol_, address signer_, uint256 delayAllowance_, uint256 value_) NameVersion('OracleOffChain', '3.0.1') {
        symbol = symbol_;
        symbolId = keccak256(abi.encodePacked(symbol_));
        signer = signer_;
        delayAllowance = delayAllowance_;
        value = value_;
    }

    function getValue() external view returns (uint256 val) {
        if (block.timestamp >= timestamp + delayAllowance) {
            revert(string(abi.encodePacked(
                bytes('OracleOffChain.getValue: '), bytes(symbol), bytes(' expired')
            )));
        }
        require((val = value) != 0, 'OracleOffChain.getValue: 0');
    }

    function updateValue(
        uint256 timestamp_,
        uint256 value_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external returns (bool)
    {
        uint256 lastTimestamp = timestamp;
        if (timestamp_ > lastTimestamp) {
            if (v_ == 27 || v_ == 28) {
                bytes32 message = keccak256(abi.encodePacked(symbolId, timestamp_, value_));
                bytes32 hash = keccak256(abi.encodePacked('\x19Ethereum Signed Message:\n32', message));
                address signatory = ecrecover(hash, v_, r_, s_);
                if (signatory == signer) {
                    timestamp = timestamp_;
                    value = value_;
                    emit NewValue(timestamp_, value_);
                    return true;
                }
            }
        }
        return false;
    }

}
