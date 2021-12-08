// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import './ISymbolManager.sol';
import './SymbolManagerStorage.sol';

contract SymbolManager is SymbolManagerStorage {

    function setImplementation(address newImplementation) external _onlyAdmin_ {
        address oldImplementation = implementation;
        if (oldImplementation != address(0)) {
            require(
                ISymbolManager(oldImplementation).pool() == ISymbolManager(newImplementation).pool(),
                'SymbolManager.setImplementation: wrong pool'
            );
        }
        implementation = newImplementation;
        emit NewImplementation(newImplementation);
    }

    fallback() external {
        address imp = implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), imp, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

}
