// SPDX-License-Identifier: UNLICENSED
//@todo: Add whitelisted collection
pragma solidity ^0.8.13;

import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "src/ClaimBuyouts.sol";

contract Vault is ERC721Holder, ERC1155Supply {
    IERC721 immutable vaultNftAddy;
    
    //@default wait time
    uint64 constant minimumWaitTime = 1 days;   


    //@note: Claim Contract
    claimBuyOuts immutable claimContract;


    struct buyOutDetails {
        uint256 lastBidPrice;

        uint64 lastBidTime;
        uint8 buyOutStarted;
        address lastBidder;
    }

    //@note: Minimum Price Mapping
    mapping(uint256 => uint256) public minimumPriceMapping;

    mapping(uint256 => buyOutDetails) public buyOutDetailsMapping;

    mapping(address => uint256) public depositAmount;
    
    
    constructor(IERC721 _nftAddress, claimBuyOuts _claimContract) {
        vaultNftAddy = _nftAddress;
        claimContract = _claimContract;
    }

    //@todo: Only Controller should call this
    //@param: The tokenId you want to deposit into the vault
    //@param: the fractions you want to divide the nft's into

    function deposit(
        uint256 _tokenId,
        uint256 _fractions,
        uint256 _minimumPrice
    ) external {
        minimumPriceMapping[_tokenId] = _minimumPrice;

        vaultNftAddy.safeTransferFrom(msg.sender, address(this), _tokenId);
        _mint(msg.sender, _tokenId, _fractions);
    }


    //@todo: Only has to call the first time buyout has started
    //@Need to Call only the first time

    //@issue: Can Initialise a buyout without having the token id 
    function initiateBuyout(uint256 _tokenId) external {
        //@Directly use here to save an mload
        
        require(
            msg.value > minimumPriceMapping[_tokenId],
            "The amount is too low"
        );

        require(buyOutDetailsMapping[_tokenId].buyOutStarted !=1,
            "Buyout has already initialised");

        require(vaultNftAddy.ownerOf(_tokenId) == address(this),"Nft not found");

        //@note: I can directly do sstore instead of sloading it and caching the value to save the gas
        buyOutDetailsMapping[_tokenId].lastBidPrice = msg.value;

        buyOutDetailsMapping[_tokenId].lastBidTime = uint64(block.timestamp);

        buyOutDetailsMapping[_tokenId].buyOutStarted = 1;

        buyOutDetailsMapping[_tokenId].lastBidder = msg.sender;
    }

    //@todo: Only controller should cal lthis function
    //@note: This will save gas for subsequent bidders

    //@note: Instead of sending directly allow the user to claim from the contract 
    function bidOnNft(uint256 _tokenId) external {
        buyOutDetails memory buyoutCache = buyOutDetailsMapping[_tokenId];

        require(buyoutCache.buyOutStarted == 1, "Buyout hasn't initiated yet");

        require(msg.value > buyoutCache.lastBidPrice, "Minimum Bid amount must be greater than last bid ");

        buyoutCache.lastBidTime = uint64(block.timestamp);

        buyoutCache.lastBidPrice = msg.value;

        buyoutCache.lastBidder = msg.sender;
    
        depositAmount[msg.sender] = depositAmount[msg.sender] + msg.value;
        //@note: Check whether the buyOutStarted is being changed over here 
        buyOutDetailsMapping[_tokenId] = buyoutCache;
    }

        //@todo: Only controller should cal lthis function

        //@todo: Send the ether to the claimContract along with token Id details(imp)

        /*@todo : Security consideration 
                1) Should this be called by anyone 
                2) Should this be called only by last Bidder*/


    function endBid(uint256 _tokenId) external {
        buyOutDetails memory buyoutCache = buyOutDetailsMapping[_tokenId];


        //@note:caching the last deposit
        address lastDepositor = buyoutCache.lastBidder;

        require(buyoutCache.buyOutStarted == 1,"Buyout hasn't initialised yet");

        require((buyoutCache.lastBidTime + minimumWaitTime) >= block.timestamp, "Cannot Call end bid now");

         depositAmount[lastDepositor] = depositAmount[lastDepositor] - buyoutCache.lastBidPrice;


        (bool success,) = address(claimContract).call{value: buyoutCache.lastBidPrice}
                        (abi.encodeWithSignature("receiveDeposit(bytes32)", 
                        keccak256(abi.encodePacked(address(this),_tokenId))));

        require(success,"Transfer Failed");

        delete buyOutDetailsMapping[_tokenId];

        delete minimumPriceMapping[_tokenId];


        try vaultNftAddy.safeTransferFrom(address(this), lastDepositor, _tokenId){
            //@emit an event here 
        }
        catch{
            vaultNftAddy.approve(address(claimContract), _tokenId);
            claimContract.depositFailedTransferNft(vaultNftAddy, _tokenId, lastDepositor);
        }

    }


    function withdraw(uint256 _tokenId) external {

        _burn(msg.sender,_tokenId,totalSupply(_tokenId));

         delete minimumPriceMapping[_tokenId];
        
        try vaultNftAddy.safeTransferFrom(address(this), msg.sender, _tokenId){
            //@emit an event here 
        }
        //@note: If the claims fails push it to the claims array mapping 
        catch{
            vaultNftAddy.approve(address(claimContract), _tokenId);
            claimContract.depositFailedTransferNft(vaultNftAddy, _tokenId, msg.sender);
        }
    }

    //@note: Should Be called by ClaimBuyouts.sol
    function burn(address from,uint256 id) external{

        require(msg.sender == address(claimContract),"Not Claim Contract");

        uint256 amount = balanceOf(from, id);

        _burn(from,id,amount);
    }

    function withdrawBidMoney(uint256 _amount) external {
        //@note:Chaching here to save extra sloads
        uint256 balance = depositAmount[msg.sender];

        require(_amount >= balance, "Balance Exceeding amount");

        depositAmount[msg.sender] = depositAmount[msg.sender] - _amount;

        (bool success,) = payable(msg.sender).call{value:_amount}();
        require(success,"Transfer Failed");
    }


     



}
