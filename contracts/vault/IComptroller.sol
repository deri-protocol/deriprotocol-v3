// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface IComptroller {

    function isComptroller() external view returns (bool);

    function checkMembership(address account, address vToken) external view returns (bool);

    function getAssetsIn(address account) external view returns (address[] memory);

    function getAccountLiquidity(address account) external view returns (uint256 error, uint256 liquidity, uint256 shortfall);

    function getHypotheticalAccountLiquidity(address account, address vTokenModify, uint256 redeemTokens, uint256 borrowAmount)
    external view returns (uint256 error, uint256 liquidity, uint256 shortfall);

    function enterMarkets(address[] memory vTokens) external returns (uint256[] memory errors);

    function exitMarket(address vToken) external returns (uint256 error);

    function getXVSAddress() external view returns (address);

    function claimVenus(address account) external;

}
