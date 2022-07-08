// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import '../token/IERC20.sol';
import '../token/IDToken.sol';
import '../oracle/IOracleManager.sol';
import '../symbol/ISymbolManager.sol';
import '../utils/IPrivileger.sol';
import '../utils/IRewardVault.sol';
import './PoolStorage.sol';
import '../utils/NameVersion.sol';
import '../library/SafeMath.sol';
import '../library/SafeERC20.sol';

contract PoolImplementationLite is PoolStorage, NameVersion {

    event CollectProtocolFee(address indexed collector, uint256 amount);

    event AddLiquidity(
        uint256 indexed lTokenId,
        address indexed underlying,
        uint256 amount,
        int256 newLiquidity
    );

    event RemoveLiquidity(
        uint256 indexed lTokenId,
        address indexed underlying,
        uint256 amount,
        int256 newLiquidity
    );

    event AddMargin(
        uint256 indexed pTokenId,
        address indexed underlying,
        uint256 amount,
        int256 newMargin
    );

    event RemoveMargin(
        uint256 indexed pTokenId,
        address indexed underlying,
        uint256 amount,
        int256 newMargin
    );

    using SafeMath for uint256;
    using SafeMath for int256;
    using SafeERC20 for IERC20;

    int256 constant ONE = 1e18;
    uint256 constant UONE = 1e18;
    uint256 constant UMAX = type(uint256).max / UONE;

    address public immutable tokenB0;

    IDToken public immutable lToken;

    IDToken public immutable pToken;

    IOracleManager public immutable oracleManager;

    ISymbolManager public immutable symbolManager;

    IPrivileger public immutable privileger;

    IRewardVault public immutable rewardVault;

    int256 public immutable poolInitialMarginMultiplier;

    int256 public immutable protocolFeeCollectRatio;

    int256 public immutable minLiquidationReward;

    int256 public immutable maxLiquidationReward;

    int256 public immutable liquidationRewardCutRatio;

    constructor (
        address[7] memory addresses_,
        uint256[5] memory parameters_
    ) NameVersion('PoolImplementation', '3.0.2')
    {
        tokenB0 = addresses_[0];
        lToken = IDToken(addresses_[1]);
        pToken = IDToken(addresses_[2]);
        oracleManager = IOracleManager(addresses_[3]);
        symbolManager = ISymbolManager(addresses_[4]);
        privileger = IPrivileger(addresses_[5]);
        rewardVault = IRewardVault(addresses_[6]);

        require(
            IERC20(tokenB0).decimals() == 18,
            'PoolImplementationLite.constructor: tokenB0 must be in decimals 18'
        );

        poolInitialMarginMultiplier = parameters_[0].utoi();
        protocolFeeCollectRatio = parameters_[1].utoi();
        minLiquidationReward = parameters_[2].utoi();
        maxLiquidationReward = parameters_[3].utoi();
        liquidationRewardCutRatio = parameters_[4].utoi();
    }

    function collectProtocolFee() external _onlyAdmin_ {
        require(protocolFeeCollector != address(0), 'PoolImplementationLite.collectProtocolFee: collector not set');
        uint256 amount = protocolFeeAccrued.itou();
        protocolFeeAccrued = 0;
        IERC20(tokenB0).safeTransfer(protocolFeeCollector, amount);
        emit CollectProtocolFee(protocolFeeCollector, amount);
    }

    //================================================================================

    function addLiquidity(address underlying, uint256 amount, OracleSignature[] memory oracleSignatures) external _reentryLock_
    {
        // Keep `underlying` parameter to maintain the same interface as regular V3 pool implementation
        require(underlying == tokenB0, 'PoolImplementationLite.addLiquidity: only tokenB0');
        _updateOracles(oracleSignatures);

        Data memory data = _initializeData();
        _getLpInfo(data, true);

        ISymbolManager.SettlementOnAddLiquidity memory s =
        symbolManager.settleSymbolsOnAddLiquidity(data.liquidity + data.lpsPnl);

        int256 undistributedPnl = s.funding - s.deltaTradersPnl;
        if (undistributedPnl != 0) {
            data.lpsPnl += undistributedPnl;
            data.cumulativePnlPerLiquidity += undistributedPnl * ONE / data.liquidity;
        }

        uint256 balanceB0 = IERC20(tokenB0).balanceOf(address(this));
        _settleLp(data);
        _transferIn(data, amount);

        if (address(rewardVault) != address(0)) {
            int256 newLiquidityB0 = data.amountB0;
            rewardVault.updateVault(data.liquidity.itou(), data.tokenId, data.lpLiquidity.itou(), balanceB0, newLiquidityB0);
        }

        int256 newLiquidity = data.amountB0;
        data.liquidity += newLiquidity - data.lpLiquidity;
        data.lpLiquidity = newLiquidity;

        liquidity = data.liquidity;
        lpsPnl = data.lpsPnl;
        cumulativePnlPerLiquidity = data.cumulativePnlPerLiquidity;

        LpInfo storage info = lpInfos[data.tokenId];
        info.amountB0 = data.amountB0;
        info.liquidity = data.lpLiquidity;
        info.cumulativePnlPerLiquidity = data.lpCumulativePnlPerLiquidity;

        emit AddLiquidity(data.tokenId, tokenB0, amount, newLiquidity);
    }

    function removeLiquidity(address underlying, uint256 amount, OracleSignature[] memory oracleSignatures) external _reentryLock_
    {
        require(underlying == tokenB0, 'PoolImplementationLite.removeLiquidity: only tokenB0');
        _updateOracles(oracleSignatures);

        Data memory data = _initializeData();
        _getLpInfo(data, false);

        int256 removedLiquidity = amount.utoi().min(data.amountB0);

        require(data.liquidity + data.lpsPnl > removedLiquidity, 'PoolImplementationLite.removeLiquidity: removedLiquidity > total liquidity');
        ISymbolManager.SettlementOnRemoveLiquidity memory s =
        symbolManager.settleSymbolsOnRemoveLiquidity(data.liquidity + data.lpsPnl, removedLiquidity);
        require(s.removeLiquidityPenalty >= 0, 'PoolImplementationLite.removedLiquidity: negative penalty');

        int256 undistributedPnl = s.funding - s.deltaTradersPnl + s.removeLiquidityPenalty;
        data.lpsPnl += undistributedPnl;
        data.cumulativePnlPerLiquidity += undistributedPnl * ONE / data.liquidity;
        data.amountB0 -= s.removeLiquidityPenalty;

        uint256 balanceB0 = IERC20(tokenB0).balanceOf(address(this));
        _settleLp(data);
        _transferOut(data, amount);

        if (address(rewardVault) != address(0)) {
            int256 newLiquidityB0 = data.amountB0;
            rewardVault.updateVault(data.liquidity.itou(), data.tokenId, data.lpLiquidity.itou(), balanceB0, newLiquidityB0);
        }

        int256 newLiquidity = data.amountB0;
        data.liquidity += newLiquidity - data.lpLiquidity;
        data.lpLiquidity = newLiquidity;

        require(
            data.liquidity * ONE >= s.initialMarginRequired * poolInitialMarginMultiplier,
            'PoolImplementationLite.removeLiquidity: pool insufficient liquidity'
        );

        liquidity = data.liquidity;
        lpsPnl = data.lpsPnl;
        cumulativePnlPerLiquidity = data.cumulativePnlPerLiquidity;

        LpInfo storage info = lpInfos[data.tokenId];
        info.amountB0 = data.amountB0;
        info.liquidity = data.lpLiquidity;
        info.cumulativePnlPerLiquidity = data.lpCumulativePnlPerLiquidity;

        emit RemoveLiquidity(data.tokenId, tokenB0, amount, newLiquidity);
    }

    function addMargin(address underlying, uint256 amount, OracleSignature[] memory oracleSignatures) external _reentryLock_
    {
        require(underlying == tokenB0, 'PoolImplementationLite.removeLiquidity: only tokenB0');
        _updateOracles(oracleSignatures);

        Data memory data;
        data.account = msg.sender;

        _getTdInfo(data, true);
        _transferIn(data, amount);

        int256 newMargin = data.amountB0;

        TdInfo storage info = tdInfos[data.tokenId];
        info.amountB0 = data.amountB0;

        emit AddMargin(data.tokenId, tokenB0, amount, newMargin);
    }

    function removeMargin(address underlying, uint256 amount, OracleSignature[] memory oracleSignatures) external _reentryLock_
    {
        require(underlying == tokenB0, 'PoolImplementationLite.removeLiquidity: only tokenB0');
        _updateOracles(oracleSignatures);

        Data memory data = _initializeData();
        _getTdInfo(data, false);

        ISymbolManager.SettlementOnRemoveMargin memory s =
        symbolManager.settleSymbolsOnRemoveMargin(data.tokenId, data.liquidity + data.lpsPnl);

        int256 undistributedPnl = s.funding - s.deltaTradersPnl;
        data.lpsPnl += undistributedPnl;
        data.cumulativePnlPerLiquidity += undistributedPnl * ONE / data.liquidity;

        data.amountB0 -= s.traderFunding;

        _transferOut(data, amount);

        require(
            data.amountB0 + s.traderPnl >= s.traderInitialMarginRequired,
            'PoolImplementationLite.removeMargin: insufficient margin'
        );

        lpsPnl = data.lpsPnl;
        cumulativePnlPerLiquidity = data.cumulativePnlPerLiquidity;

        tdInfos[data.tokenId].amountB0 = data.amountB0;

        emit RemoveMargin(data.tokenId, tokenB0, amount, data.amountB0);
    }

    function trade(string memory symbolName, int256 tradeVolume, int256 priceLimit, OracleSignature[] memory oracleSignatures) external _reentryLock_
    {
        _updateOracles(oracleSignatures);

        bytes32 symbolId = keccak256(abi.encodePacked(symbolName));

        Data memory data = _initializeData();
        _getTdInfo(data, false);

        ISymbolManager.SettlementOnTrade memory s =
        symbolManager.settleSymbolsOnTrade(data.tokenId, symbolId, tradeVolume, data.liquidity + data.lpsPnl, priceLimit);

        int256 collect = s.tradeFee * protocolFeeCollectRatio / ONE;
        int256 undistributedPnl = s.funding - s.deltaTradersPnl + s.tradeFee - collect + s.tradeRealizedCost;
        data.lpsPnl += undistributedPnl;
        data.cumulativePnlPerLiquidity += undistributedPnl * ONE / data.liquidity;

        data.amountB0 -= s.traderFunding + s.tradeFee + s.tradeRealizedCost;
        int256 margin = data.amountB0;

        require(
            (data.liquidity + data.lpsPnl) * ONE >= s.initialMarginRequired * poolInitialMarginMultiplier,
            'PoolImplementationLite.trade: pool insufficient liquidity'
        );
        require(
            margin + s.traderPnl >= s.traderInitialMarginRequired,
            'PoolImplementationLite.trade: insufficient margin'
        );

        lpsPnl = data.lpsPnl;
        cumulativePnlPerLiquidity = data.cumulativePnlPerLiquidity;
        protocolFeeAccrued += collect;

        tdInfos[data.tokenId].amountB0 = data.amountB0;
    }

    function liquidate(uint256 pTokenId, OracleSignature[] memory oracleSignatures) external _reentryLock_
    {
        require(
            address(privileger) == address(0) || privileger.isQualifiedLiquidator(msg.sender),
            'PoolImplementationLite.liquidate: unqualified liquidator'
        );

        _updateOracles(oracleSignatures);

        require(
            pToken.exists(pTokenId),
            'PoolImplementationLite.liquidate: nonexistent pTokenId'
        );

        Data memory data = _initializeData();
        data.amountB0 = tdInfos[pTokenId].amountB0;

        ISymbolManager.SettlementOnLiquidate memory s =
        symbolManager.settleSymbolsOnLiquidate(pTokenId, data.liquidity + data.lpsPnl);

        int256 undistributedPnl = s.funding - s.deltaTradersPnl + s.traderRealizedCost;

        data.amountB0 -= s.traderFunding;
        int256 margin = data.amountB0;

        require(
            s.traderMaintenanceMarginRequired > 0,
            'PoolImplementationLite.liquidate: no position'
        );
        require(
            margin + s.traderPnl < s.traderMaintenanceMarginRequired,
            'PoolImplementationLite.liquidate: cannot liquidate'
        );

        data.amountB0 -= s.traderRealizedCost;

        int256 reward;
        if (data.amountB0 <= minLiquidationReward) {
            reward = minLiquidationReward;
        } else {
            reward = (data.amountB0 - minLiquidationReward) * liquidationRewardCutRatio / ONE + minLiquidationReward;
            reward = reward.min(maxLiquidationReward);
        }

        undistributedPnl += data.amountB0 - reward;
        data.lpsPnl += undistributedPnl;
        data.cumulativePnlPerLiquidity += undistributedPnl * ONE / data.liquidity;

        IERC20(tokenB0).safeTransfer(msg.sender, reward.itou());

        lpsPnl = data.lpsPnl;
        cumulativePnlPerLiquidity = data.cumulativePnlPerLiquidity;

        tdInfos[pTokenId].amountB0 = 0;
    }

    //================================================================================

    struct OracleSignature {
        bytes32 oracleSymbolId;
        uint256 timestamp;
        uint256 value;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function _updateOracles(OracleSignature[] memory oracleSignatures) internal {
        for (uint256 i = 0; i < oracleSignatures.length; i++) {
            OracleSignature memory signature = oracleSignatures[i];
            oracleManager.updateValue(
                signature.oracleSymbolId,
                signature.timestamp,
                signature.value,
                signature.v,
                signature.r,
                signature.s
            );
        }
    }

    struct Data {
        int256 liquidity;
        int256 lpsPnl;
        int256 cumulativePnlPerLiquidity;

        address account;
        uint256 tokenId;
        int256 amountB0;
        int256 lpLiquidity;
        int256 lpCumulativePnlPerLiquidity;
    }

    function _initializeData() internal view returns (Data memory data) {
        data.liquidity = liquidity;
        data.lpsPnl = lpsPnl;
        data.cumulativePnlPerLiquidity = cumulativePnlPerLiquidity;
        data.account = msg.sender;
    }

    function _getLpInfo(Data memory data, bool createOnDemand) internal {
        data.tokenId = lToken.getTokenIdOf(data.account);
        if (data.tokenId == 0) {
            require(createOnDemand, 'PoolImplementationLite.getLpInfo: not LP');
            data.tokenId = lToken.mint(data.account);
        } else {
            LpInfo storage info = lpInfos[data.tokenId];
            data.amountB0 = info.amountB0;
            data.lpLiquidity = info.liquidity;
            data.lpCumulativePnlPerLiquidity = info.cumulativePnlPerLiquidity;
        }
    }

    function _getTdInfo(Data memory data, bool createOnDemand) internal {
        data.tokenId = pToken.getTokenIdOf(data.account);
        if (data.tokenId == 0) {
            require(createOnDemand, 'PoolImplementationLite.getTdInfo: not trader');
            data.tokenId = pToken.mint(data.account);
        } else {
            TdInfo storage info = tdInfos[data.tokenId];
            data.amountB0 = info.amountB0;
        }
    }

    function _settleLp(Data memory data) internal pure {
        int256 diff;
        unchecked { diff = data.cumulativePnlPerLiquidity - data.lpCumulativePnlPerLiquidity; }
        int256 pnl = diff * data.lpLiquidity / ONE;

        data.amountB0 += pnl;
        data.lpsPnl -= pnl;
        data.lpCumulativePnlPerLiquidity = data.cumulativePnlPerLiquidity;
    }

    function _transferIn(Data memory data, uint256 amount) internal {
        IERC20(tokenB0).safeTransferFrom(data.account, address(this), amount);
        data.amountB0 += amount.utoi();
    }

    function _transferOut(Data memory data, uint256 amount) internal {
        require(data.amountB0 > 0, 'PoolImplementationLite: amountB0 <= 0');
        uint256 own = data.amountB0.itou();
        if (amount >= own) {
            data.amountB0 = 0;
            IERC20(tokenB0).safeTransfer(data.account, own);
        } else {
            data.amountB0 -= amount.utoi();
            IERC20(tokenB0).safeTransfer(data.account, amount);
        }
    }

}
