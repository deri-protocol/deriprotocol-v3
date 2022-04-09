// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '../utils/IAdmin.sol';
import '../utils/INameVersion.sol';
import '../oracle/IOracleManager.sol';

interface ISwapper is IAdmin, INameVersion {

    function factory() external view returns (IUniswapV3Factory);

    function router() external view returns (ISwapRouter);

    function oracleManager() external view returns (IOracleManager);

    function tokenB0() external view returns (address);

    function tokenWETH() external view returns (address);

    function feeB0WETH() external view returns (uint24);

    function decimalsB0() external view returns (uint8);

    function maxSlippageRatio() external view returns (uint256);

    function oracleSymbolIds(address tokenBX) external view returns (bytes32);

    function setPath(string memory priceSymbol, uint24[] calldata fees, address[] calldata tokens) external;

    function getPath(address tokenBX) external view returns (bytes memory);

    function isSupportedToken(address tokenBX) external view returns (bool);

    function getTokenPrice(address tokenBX) external view returns (uint256);

    function swapExactB0ForBX(address tokenBX, uint256 amountB0)
    external returns (uint256 resultB0, uint256 resultBX);

    function swapExactBXForB0(address tokenBX, uint256 amountBX)
    external returns (uint256 resultB0, uint256 resultBX);

    function swapB0ForExactBX(address tokenBX, uint256 maxAmountB0, uint256 amountBX)
    external returns (uint256 resultB0, uint256 resultBX);

    function swapBXForExactB0(address tokenBX, uint256 amountB0, uint256 maxAmountBX)
    external returns (uint256 resultB0, uint256 resultBX);

    function swapExactB0ForETH(uint256 amountB0)
    external returns (uint256 resultB0, uint256 resultBX);

    function swapExactETHForB0()
    external payable returns (uint256 resultB0, uint256 resultBX);

    function swapB0ForExactETH(uint256 maxAmountB0, uint256 amountBX)
    external returns (uint256 resultB0, uint256 resultBX);

    function swapETHForExactB0(uint256 amountB0)
    external payable returns (uint256 resultB0, uint256 resultBX);

}
