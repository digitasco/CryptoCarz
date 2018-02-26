pragma solidity ^0.4.18;

import '../node_modules/zeppelin-solidity/contracts/token/ERC721/ERC721Token.sol';
import './CryptoCarzControl.sol';


contract CryptoCarzToken is ERC721Token, CryptoCarzControl {

    function CryptoCarzToken(address _manager) {
        manager = _manager;
    }

    function mintTokens(uint256[] _tokenIds) public whenNotPaused onlyManager {
        for (uint i = 0; i < _tokenIds.length; i++) {
            _mint(msg.sender, _tokenIds[i]);
        }
    }

    function transferTokens(address _to, uint256[] _tokenIds) public onlyManager {
        for (uint i = 0; i < _tokenIds.length; i++) {
            transfer(_to, _tokenIds[i]);
        }
    }    
    
}