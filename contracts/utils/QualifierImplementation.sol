// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import '../token/IERC20.sol';
import './QualifierStorage.sol';
import '../utils/NameVersion.sol';
import '../library/SafeERC20.sol';

contract QualifierImplementation is QualifierStorage, NameVersion {

    event Deposit(address token, address user, uint256 amount);

    event Withdraw(address token, address user, uint256 amount);

    using SafeERC20 for IERC20;

    address public immutable deri;

    constructor (address deri_) NameVersion('QualifierImplementation', '3.0.1') {
        deri = deri_;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, 'QualifierImplementation.deposit: zero amount');
        IERC20(deri).safeTransferFrom(msg.sender, address(this), amount);
        stakesTotal[deri] += amount;
        if (stakes[deri][msg.sender] == 0) {
            stakesCount[deri]++;
        }
        stakes[deri][msg.sender] += amount;
        emit Deposit(deri, msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, 'QualifierImplementation.withdraw: zero amount');
        uint256 balance = stakes[deri][msg.sender];
        require(balance >= amount, 'QualifierImplementation.withdraw: amount exceeds balance');

        if (balance == amount) {
            stakesCount[deri]--;
        }
        stakesTotal[deri] -= amount;
        stakes[deri][msg.sender] -= amount;

        IERC20(deri).safeTransfer(msg.sender, amount);
        emit Withdraw(deri, msg.sender, amount);
    }

    function isQualifiedLiquidator(address liquidator) external view returns (bool) {
        uint256 count = stakesCount[deri];
        return count > 0 && stakes[deri][liquidator] * count > stakesTotal[deri];
    }

}
