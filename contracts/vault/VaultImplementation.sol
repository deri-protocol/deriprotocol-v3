// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import '@aave/core-v3/contracts/interfaces/IPool.sol';
import '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import '@aave/core-v3/contracts/interfaces/IAaveOracle.sol';
import '@aave/core-v3/contracts/misc/interfaces/IWETH.sol';
import '@aave/periphery-v3/contracts/rewards/interfaces/IRewardsController.sol';
import '../token/IERC20.sol';
import '../library/SafeERC20.sol';
import '../utils/NameVersion.sol';

contract VaultImplementation is NameVersion {

    using SafeERC20 for IERC20;

    address public immutable pool; // Deri pool

    address public immutable weth;

    address public immutable aavePool; // AAVE pool

    address public immutable aaveOracle; // AAVE oracle

    address public immutable aaveRewardsController; // AAVE rewards controller

    uint256 public immutable vaultLiquidityMultiplier; // scale availableBorrowsBase, and format in 18 decimals, i.e. 1.25e10

    modifier _onlyPool_() {
        require(msg.sender == pool, 'VaultImplementation: only pool');
        _;
    }

    constructor (
        address pool_,
        address weth_,
        address aavePool_,
        address aaveOracle_,
        address aaveRewardsController_,
        uint256 vaultLiquidityMultiplier_
    ) NameVersion('VaultImplementation', '3.0.3') {
        pool = pool_;
        weth = weth_;
        aavePool = aavePool_;
        aaveOracle = aaveOracle_;
        aaveRewardsController = aaveRewardsController_;
        vaultLiquidityMultiplier = vaultLiquidityMultiplier_;
    }

    // Get this vault's liquidity, which will be used as liquidity/margin for LP/Trader
    function getVaultLiquidity() public view returns (uint256) {
        (, , uint256 availableBorrowsBase, , , ) = IPool(aavePool).getUserAccountData(address(this));
        return availableBorrowsBase * vaultLiquidityMultiplier;
    }

    // Get hypothetical change of liquidity, if `removeAmount` of `asset` is withdrawn
    function getHypotheticalVaultLiquidityChange(address asset, uint256 removeAmount) external view returns (uint256) {
        if (asset == address(0)) asset = weth;
        DataTypes.ReserveConfigurationMap memory config = IPool(aavePool).getConfiguration(asset);
        uint256 ltv = config.data & 0xFFFF; // Loan to value, i.e. collateral factor, with base 10000
        uint256 price = IAaveOracle(aaveOracle).getAssetPrice(asset);
        uint256 removeBorrowBase = price * removeAmount / (10 ** IERC20(asset).decimals()) * ltv / 10000;
        (, , uint256 availableBorrowsBase, , , ) = IPool(aavePool).getUserAccountData(address(this));
        if (removeBorrowBase > availableBorrowsBase) {
            removeBorrowBase = availableBorrowsBase;
        }
        return removeBorrowBase * vaultLiquidityMultiplier;
    }

    // Get the list of assets this vault's provided as collateral
    function getAssetsIn() external view returns (address[] memory) {
        DataTypes.UserConfigurationMap memory config = IPool(aavePool).getUserConfiguration(address(this));
        // Each pair of bits corresponding to user collateral (higer bit) / borrow (lower bit) status
        uint256 data = config.data;
        address[] memory list = new address[](128); // initialize a max length list, will reduce later
        uint256 index = 0;
        uint16 reserveId = 0;
        while (data != 0) {
            uint256 status = data & 2;
            if (status != 0) {
                list[index++] = IPoolComplement(aavePool).getReserveAddressById(reserveId);
            }
            reserveId++;
            data >>= 2;
        }
        assembly {
            mstore(list, index)
        }
        return list;
    }

    // Get underlying balance of market, with interest
    function getAssetBalance(address market) external view returns (uint256) {
        return IERC20(market).balanceOf(address(this));
    }

    // Deposit ETH as collateral
    function mint() external payable _onlyPool_ {
        IWETH(weth).deposit{value: msg.value}();
        _approveAavePool(weth, msg.value);
        IPool(aavePool).supply(weth, msg.value, address(this), 0);
    }

    // Deposit ERC20 as collateral
    function mint(address asset, uint256 amount) external _onlyPool_ {
        _approveAavePool(asset, amount);
        IPool(aavePool).supply(asset, amount, address(this), 0);
    }

    // Withdraw asset, returns the actual amount withdrawn and send them to Pool directly
    function redeem(address asset, uint256 amount) external _onlyPool_ returns (uint256 withdrawnAmount) {
        if (asset == address(0)) {
            // redeem ETH
            withdrawnAmount = IPool(aavePool).withdraw(weth, amount, address(this));
            IWETH(weth).withdraw(withdrawnAmount);
            transfer(address(0), pool, withdrawnAmount);
        } else {
            // redeem ERC20
            withdrawnAmount = IPool(aavePool).withdraw(asset, amount, pool);
        }
    }

    function transfer(address asset, address to, uint256 amount) public _onlyPool_ {
        if (asset == address(0)) {
            (bool success, ) = payable(to).call{value: amount}('');
            require(success, 'VaultImplementation.transfer: send ETH fail');
        } else {
            IERC20(asset).safeTransfer(to, amount);
        }
    }

    function transferAll(address asset, address to) external _onlyPool_ returns (uint256) {
        uint256 amount = asset == address(0) ?
                         address(this).balance :
                         IERC20(asset).balanceOf(address(this));
        transfer(asset, to, amount);
        return amount;
    }

    // Claim staked AAVE onbehalf of address account
    function claimStakedAave(address[] memory markets, address reward, address account) external _onlyPool_ {
        IRewardsController(aaveRewardsController).claimRewards(markets, type(uint256).max, account, reward);
    }

    function _approveAavePool(address asset, uint256 amount) internal {
        uint256 allowance = IERC20(asset).allowance(address(this), aavePool);
        if (allowance < amount) {
            if (allowance != 0) {
                IERC20(asset).safeApprove(aavePool, 0);
            }
            IERC20(asset).safeApprove(aavePool, type(uint256).max);
        }
    }

}

interface IPoolComplement {
    function getReserveAddressById(uint16 id) external view returns (address);
}

