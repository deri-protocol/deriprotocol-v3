// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import './IDToken.sol';
import './ERC721.sol';
import '../utils/NameVersion.sol';

contract DToken is IDToken, ERC721, NameVersion {

    address public immutable pool;

    string  public name;

    string  public symbol;

    uint256 public totalMinted;

    modifier _onlyPool_() {
        require(msg.sender == pool, 'DToken: only pool');
        _;
    }

    constructor (string memory name_, string memory symbol_, address pool_) NameVersion('DToken', '3.0.1') {
        name = name_;
        symbol = symbol_;
        pool = pool_;
    }

    function exists(address owner) external view returns (bool) {
        return _exists(owner);
    }

    function exists(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId);
    }

    // tokenId existence unchecked
    function getOwnerOf(uint256 tokenId) external view returns (address) {
        return _tokenIdOwner[tokenId];
    }

    // owner existence unchecked
    function getTokenIdOf(address owner) external view returns (uint256) {
        return _ownerTokenId[owner];
    }

    function mint(address owner) external _onlyPool_ returns (uint256) {
        require(!_exists(owner), 'DToken.mint: existent owner');

        uint256 tokenId = ++totalMinted;
        _ownerTokenId[owner] = tokenId;
        _tokenIdOwner[tokenId] = owner;

        emit Transfer(address(0), owner, tokenId);
        return tokenId;
    }

    function burn(uint256 tokenId) external _onlyPool_ {
        address owner = _tokenIdOwner[tokenId];
        require(owner != address(0), 'DToken.burn: nonexistent tokenId');

        delete _ownerTokenId[owner];
        delete _tokenIdOwner[tokenId];
        delete _tokenIdOperator[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

}
