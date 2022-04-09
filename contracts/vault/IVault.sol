// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import '../utils/INameVersion.sol';

interface IVault is INameVersion {

    function pool() external view returns (address);

    function weth() external view returns (address);

    function aavePool() external view returns (address);

    function aaveOracle() external view returns (address);

    function aaveRewardsController() external view returns (address);

    function vaultLiquidityMultiplier() external view returns (uint256);

    function getVaultLiquidity() external view  returns (uint256);

    function getHypotheticalVaultLiquidityChange(address asset, uint256 removeAmount) external view returns (uint256);

    function getAssetsIn() external view returns (address[] memory);

    function getAssetBalance(address market) external view returns (uint256);

    function mint() external payable;

    function mint(address asset, uint256 amount) external;

    function redeem(address asset, uint256 amount) external returns (uint256 withdrawnAmount);

    function transfer(address asset, address to, uint256 amount) external;

    function transferAll(address asset, address to) external returns (uint256);

    function claimStakedAave(address[] memory markets, address reward, address to) external;

}
