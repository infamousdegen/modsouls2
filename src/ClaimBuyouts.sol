

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "lib/solmate/src/utils/FixedPointMathLib.sol";

import "src/vaultFactory.sol";

import "src/Vault.sol";

import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";




contract claimBuyOuts{
    using FixedPointMathLib for uint256;

    //keccak Hash of Vault address and their tokenId
    mapping(bytes32 => uint256) public totalClaimAmount;



    VaultFactory immutable vaultFactory;

    //@note: First depositorAddress
    //@note: Inside address is for nft contract
    //@note: uint256 = nft tokenId
    mapping(address => mapping(address =>uint256[])) public failedNftClaim;

    constructor(VaultFactory _vaultFactory){

        vaultFactory = _vaultFactory;

    }

    //@todo: Should be called by the controller
    //@param data will be the keccak hash of vault and their tokenId
    function receiveDeposit(bytes32 data) payable public {
        totalClaimAmount[data] = totalClaimAmount[data] + msg.value;
    }


    //@todo: Vault Registry
    function claimBalance(address _NftContract,uint256 _tokenId) external {

        Vault vault = Vault(vaultFactory.vaultRegistry(_NftContract));

        //@note: this is the total UnclaimedBalance
        uint256 corresPondingBalance = totalClaimAmount[keccak256(
                                        abi.encodePacked(address(vault),_tokenId))];
        


        uint256 amountToSend = vault.balanceOf(msg.sender,_tokenId).mulDivUp(
                               corresPondingBalance,vault.totalSupply(_tokenId));

        vault.burn(msg.sender,_tokenId);

        (bool success,) = payable(msg.sender).call{value:amountToSend}("");
        require(success,"Transfer failed");
    }


    //@note:Should be only called by Vault.sol
    function depositFailedTransferNft(
            IERC721 _NftContract,
            uint256 _tokenId,
            address _bidder) 
            external {
                
            _NftContract.safeTransferFrom(msg.sender, address(this), _tokenId);
            failedNftClaim[_bidder][address(_NftContract)].push(_tokenId);
    }

    function claimAllFailedNft(IERC721 _NftContract) external{

        uint256[] memory tokenIdArray = failedNftClaim[msg.sender][address(_NftContract)];

        for(uint256 i; i < tokenIdArray.length;){
            _NftContract.safeTransferFrom(address(this), msg.sender, tokenIdArray[i]);
            unchecked {
                ++i;
            }
        }

    }

    

     




}