// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import '../utils/INameVersion.sol';
import '../utils/IAdmin.sol';

interface IPool is INameVersion, IAdmin {

    function implementation() external view returns (address);

    function protocolFeeCollector() external view returns (address);

    function liquidity() external view returns (int256);

    function lpsPnl() external view returns (int256);

    function cumulativePnlPerLiquidity() external view returns (int256);

    function protocolFeeAccrued() external view returns (int256);

    function setImplementation(address newImplementation) external;

    function addMarket(address market) external;

    function approveSwapper(address underlying) external;

    function claimVenusLp(address account) external;

    function claimVenusTrader(address account) external;

    function addLiquidity(address underlying, uint256 amount) external payable;

    function removeLiquidity(address underlying, uint256 amount) external;

    function addMargin(address underlying, uint256 amount) external payable;

    function removeMargin(address underlying, uint256 amount) external;

    function trade(string memory symbolName, int256 tradeVolume) external;

    function liquidate(uint256 pTokenId) external;

}
