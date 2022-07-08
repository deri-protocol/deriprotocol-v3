// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface IRewardVault {

	function updateVault(uint256, uint256, uint256, uint256, int256) external;

	function initialize(address) external;

	function initialize(address, address) external;

	function claim(address) external;

	function pending(address, uint256) view external returns (uint256);

	function pending(address, address) view external returns (uint256);

	function calRewardPerLiquidityPerSecond(address) view external returns (uint256, uint256);

	function updateB0Liquidity(uint256, int256) external;

}
