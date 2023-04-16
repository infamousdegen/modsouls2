// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "lib/solmate/src/utils/FixedPointMathLib.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "src/Vault.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import "src/ClaimBuyouts.sol";

contract VaultFactory is Ownable2Step{


    
    //@todo: Make this updatable
    claimBuyOuts public claimContract;

    //@registry of all vaults deployed 
    mapping(address => address) public vaultRegistry;

    function deployVault(IERC721 _address) external returns(Vault){
        require(vaultRegistry[address(_address)] == address(0),"Vault already exists");

        Vault vaultAddy = new Vault(_address,claimContract);

        vaultRegistry[address(_address)] = address(vaultAddy);

        return(vaultAddy);
    }


    function updateClaimContract(claimBuyOuts _claimContract) external onlyOwner {
        claimContract = _claimContract;
    }

}