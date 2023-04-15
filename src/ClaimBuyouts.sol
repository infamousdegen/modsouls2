

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


    address immutable controller;

    vaultFactory immutable vaultFactory;

    //@note: First depositorAddress
    //@note: Inside address is for nft contract
    //@note: uint256 = nft tokenId
    mapping(address => mapping(address =>uint256[])) public failedNftClaim;

    constructor(address _controller, vaultFactory _vaultFactory){
 
        controller = _controller;

        vaultFactory = _vaultFactory;

    }

    //@todo: Should be called by the controller
    //@param data will be the keccak hash of vault and their tokenId
    function receiveDeposit(bytes32 data) payable external {
        totalClaimAmount[data] = totalClaimAmount[data] + msg.value;
    }


    //@todo: Vault Registry
    function claimBalance(address _NftContract,uint256 _tokenId) external {

        Vault vault = vaultFactory.vaultRegistry(_NftContract);

        //@note: this is the total UnclaimedBalance
        uint256 corresPondingBalance = totalClaimAmount[keccak256(
                                        abi.encodePacked(address(vault),_tokenId))];

        uint256 amountToSend = vault.balanceOf(msg.sender,_tokenId).mulDivUp(
                               corresPondingBalance,vault.totalSupply(_tokenId));

        require(vault.burn(msg.sender,_tokenId),"Burn Failed");

        payable(msg.sender).call{value:amountToSend};
    }


    //@note:Should be only called by Vault.sol
    function depositFailedTransferNft(
            IERC721 _NftContract,
            uint256 _tokenId,
            address _bidder) 
            external {
                
            require(_NftContract.safeTransferFrom(msg.sender, address(this), _tokenId));
            failedNftClaim[_bidder][_NftContract].push(_tokenId);
    }

    function claimAllFailedNft(IERC721 _NftContract) external{

        uint256[] memory tokenIdArray = failedNftClaim[msg.sender][_NftContract];

        for(uint256 i; i < tokenIdArray.length;){
            _NftContract.safeTransferFrom(address(this), msg.sender, tokenIdArray[i]);
            unchecked {
                ++i;
            }
        }

    }

    

     




}