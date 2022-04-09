// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

// AAVE AToken Interface
interface IMarket {

    function UNDERLYING_ASSET_ADDRESS() external view returns (address);

    function POOL() external view returns (address);

}
