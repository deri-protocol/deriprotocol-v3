// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import './IVToken.sol';
import './IComptroller.sol';
import '../token/IERC20.sol';
import '../library/SafeERC20.sol';
import '../utils/NameVersion.sol';

contract VaultImplementation is NameVersion {

    using SafeERC20 for IERC20;

    uint256 constant ONE = 1e18;

    address public immutable pool;

    address public immutable comptroller;

    address public immutable vTokenETH;

    address public immutable tokenXVS;

    uint256 public immutable vaultLiquidityMultiplier;

    modifier _onlyPool_() {
        require(msg.sender == pool, 'VaultImplementation: only pool');
        _;
    }

    constructor (
        address pool_,
        address comptroller_,
        address vTokenETH_,
        uint256 vaultLiquidityMultiplier_
    ) NameVersion('VaultImplementation', '3.0.1') {
        pool = pool_;
        comptroller = comptroller_;
        vTokenETH = vTokenETH_;
        vaultLiquidityMultiplier = vaultLiquidityMultiplier_;
        tokenXVS = IComptroller(comptroller_).getXVSAddress();

        require(
            IComptroller(comptroller_).isComptroller(),
            'VaultImplementation.constructor: not comptroller'
        );
        require(
            IVToken(vTokenETH_).isVToken(),
            'VaultImplementation.constructor: not vToken'
        );
        require(
            keccak256(abi.encodePacked(IVToken(vTokenETH_).symbol())) == keccak256(abi.encodePacked('vBNB')),
            'VaultImplementation.constructor: not vBNB'
        );
    }

    // Get this vault's liquidity, which will be used as liquidity/margin for LP/Trader, returns in 18 decimals
    function getVaultLiquidity() external view returns (uint256) {
        (uint256 err, uint256 liquidity, uint256 shortfall) = IComptroller(comptroller).getAccountLiquidity(address(this));
        require(err == 0 && shortfall == 0, 'VaultImplementation.getVaultLiquidity: error');
        return liquidity * vaultLiquidityMultiplier / ONE;
    }

    // Get hypothetical liquidity, if `redeemVTokens` is redeemed, returns in 18 decimals
    function getHypotheticalVaultLiquidity(address vTokenModify, uint256 redeemVTokens)
    external view returns (uint256)
    {
        (uint256 err, uint256 liquidity, uint256 shortfall) =
        IComptroller(comptroller).getHypotheticalAccountLiquidity(address(this), vTokenModify, redeemVTokens, 0);
        require(err == 0 && shortfall == 0, 'VaultImplementation.getHypotheticalVaultLiquidity: error');
        return liquidity * vaultLiquidityMultiplier / ONE;
    }

    function isInMarket(address vToken) public view returns (bool) {
        return IComptroller(comptroller).checkMembership(address(this), vToken);
    }

    function getMarketsIn() external view returns (address[] memory) {
        return IComptroller(comptroller).getAssetsIn(address(this));
    }

    function getBalances(address vToken) external view returns (uint256 vTokenBalance, uint256 underlyingBalance) {
        vTokenBalance = IVToken(vToken).balanceOf(address(this));
        if (vTokenBalance != 0) {
            uint256 exchangeRate = IVToken(vToken).exchangeRateStored();
            underlyingBalance = vTokenBalance * exchangeRate / ONE;
        }
    }

    function enterMarket(address vToken) external _onlyPool_ {
        if (vToken != vTokenETH) {
            IERC20 underlying = IERC20(IVToken(vToken).underlying());
            uint256 allowance = underlying.allowance(address(this), vToken);
            if (allowance != type(uint256).max) {
                if (allowance != 0) {
                    underlying.safeApprove(vToken, 0);
                }
                underlying.safeApprove(vToken, type(uint256).max);
            }
        }
        address[] memory markets = new address[](1);
        markets[0] = vToken;
        uint256[] memory res = IComptroller(comptroller).enterMarkets(markets);
        require(res[0] == 0, 'VaultImplementation.enterMarket: error');
    }

    function exitMarket(address vToken) external _onlyPool_ {
        if (vToken != vTokenETH) {
            IERC20 underlying = IERC20(IVToken(vToken).underlying());
            uint256 allowance = underlying.allowance(address(this), vToken);
            if (allowance != 0) {
                underlying.safeApprove(vToken, 0);
            }
        }
        require(
            IComptroller(comptroller).exitMarket(vToken) == 0,
            'VaultImplementation.exitMarket: error'
        );
    }

    function mint() external payable _onlyPool_ {
        IVToken(vTokenETH).mint{value: msg.value}();
    }

    function mint(address vToken, uint256 amount) external _onlyPool_ {
        require(IVToken(vToken).mint(amount) == 0, 'VaultImplementation.mint: error');
    }

    function redeem(address vToken, uint256 amount) public _onlyPool_ {
        require(IVToken(vToken).redeem(amount) == 0, 'VaultImplementation.redeem: error');
    }

    function redeemAll(address vToken) external _onlyPool_ {
        uint256 balance = IVToken(vToken).balanceOf(address(this));
        if (balance != 0) {
            redeem(vToken, balance);
        }
    }

    function redeemUnderlying(address vToken, uint256 amount) external _onlyPool_ {
        require(
            IVToken(vToken).redeemUnderlying(amount) == 0,
            'VaultImplementation.redeemUnderlying: error'
        );
    }

    function transfer(address underlying, address to, uint256 amount) public _onlyPool_ {
        if (underlying == address(0)) {
            (bool success, ) = payable(to).call{value: amount}('');
            require(success, 'VaultImplementation.transfer: send ETH fail');
        } else {
            IERC20(underlying).safeTransfer(to, amount);
        }
    }

    function transferAll(address underlying, address to) external _onlyPool_ returns (uint256) {
        uint256 amount = underlying == address(0) ?
                         address(this).balance :
                         IERC20(underlying).balanceOf(address(this));
        transfer(underlying, to, amount);
        return amount;
    }

    function claimVenus(address account) external _onlyPool_ {
        IComptroller(comptroller).claimVenus(address(this));
        uint256 balance = IERC20(tokenXVS).balanceOf(address(this));
        if (balance != 0) {
            IERC20(tokenXVS).safeTransfer(account, balance);
        }
    }

}
