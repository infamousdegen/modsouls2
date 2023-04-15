

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "lib/solmate/src/utils/FixedPointMathLib.sol";



contract claimBuyOuts{
    using FixedPointMathLib for uint256;

    //keccak Hash of Vault address and their tokenId
    mapping(bytes32 => uint256) public totalClaimAmount;


    address immutable controller;

    address immutable vaultRegistry;

    constructor(address _controller,address _vaultRegistry){
 
        controller = _controller;

        vaultRegistry = _vaultRegistry;

    }

    //@todo: Should be called by the controller
    //@param data will be the keccak hash of vault and their tokenId
    function receiveDeposit(bytes32 data) payable external {
        totalClaimAmount[data] = totalClaimAmount[data] + msg.value;
    }


    //@todo: Vault Registry
    function claimBalance(address _NftContract,uint256 _tokenId) external {

        /*Query Vault Address From Here 

        */

        uint256 totalSupply = vault.totalSupply(_tokenId);

        uint256 balanceOf = vault.balanceOf(msg.sender,_tokenId);

        //@note: this is the total UnclaimedBalance
        uint256 corresPondingBalance = totalClaimAmount[keccak256(abi.encodePacked(address(vault),_tokenId))];

        uint256 amountToSend = balanceOf.mulDivUp(corresPondingBalance,totalSupply);

        require(vault.burn(msg.sender,_tokenId),"Burn Failed");

        payable(msg.sender).call{value:amountToSend};
    }

     




}