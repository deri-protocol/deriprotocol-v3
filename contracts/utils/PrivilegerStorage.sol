// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import '../utils/Admin.sol';

abstract contract PrivilegerStorage is Admin {

    // admin will be truned in to Timelock after deployment

    event NewImplementation(address newImplementation);

    address public implementation;

    // token address => staker address => staked amount
    mapping (address => mapping (address => uint256)) public stakes;

    // token address => staker address => staked timestamp
    mapping (address => mapping (address => uint256)) public stakeTimestamps;

    // token address => total staked amount
    mapping (address => uint256) public stakesTotal;

    // token address => count of stakers
    mapping (address => uint256) public stakesCount;

}
