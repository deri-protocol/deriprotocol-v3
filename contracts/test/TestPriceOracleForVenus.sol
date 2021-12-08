// SPDX-License-Identifier: MIT

pragma solidity ^0.5.16;

import './venus/PriceOracle.sol';
import './venus/VBep20.sol';

contract TestPriceOracleForVenus is PriceOracle {

    IOracleManager public oracleManager;

    constructor (address oracleManager_) public {
        oracleManager = IOracleManager(oracleManager_);
    }

    function getUnderlyingPrice(VToken vToken) external view returns (uint256) {
        if (compareStrings(vToken.symbol(), 'vBNB')) {
            return oracleManager.value(keccak256(abi.encodePacked('BNBUSD')));
        } else if (compareStrings(vToken.symbol(), 'vBUSD')) {
            return 1e18;
        } else {
            address underlying = address(VBep20(address(vToken)).underlying());
            return oracleManager.value(keccak256(abi.encodePacked(
                VBep20(underlying).symbol(), 'USD'
            )));
        }
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

}

interface IOracleManager {
    function value(bytes32 symbolId) external view returns (uint256);
}
