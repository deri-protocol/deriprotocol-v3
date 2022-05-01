// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface IRewardVault {

	function updateVault(uint256, uint256, uint256) external;

	function claim() external;

	function pending(uint256) view external returns (uint256);

	function pending(address) view external returns (uint256);

}
