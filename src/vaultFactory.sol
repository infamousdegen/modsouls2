// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "lib/solmate/src/utils/FixedPointMathLib.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

import "src/Vault.sol";

import "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";

contract VaultFactory is Ownable2Step{

    //@todo: Make this updatable
    address public controller;
    
    //@todo: Make this updatable
    address public claimContract;

    //@registry of all vaults deployed 
    mapping(address => address) public vaultRegistry;

    function deployVault(IERC721 _address) external{
        require(vaultRegistry[_address] == address(0),"Vault already exists");

        Vault vaultAddress = new Vault(_address,controller,claimContract);

        vaultRegistry[_address] = address(vaultAddress);
    }



    function updateController(address _controller) external onlyOwner {
        controller = _controller;

    }

    function updateClaimContract(address _claimContract) external onlyOwner {
        claimContract = _claimContract;
    }

}