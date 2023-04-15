// SPDX-License-Identifier: UNLICENSED
//@todo: Add whitelisted collection
pragma solidity ^0.8.13;

import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract Vault is ERC721Holder, ERC1155Supply {
    IERC721 vaultNftAddy;


    uint64 constant minimumWaitTime = 1 days;

    //@note:Make these struct updatable
    struct tokenIdDetails {
        uint256 minimumBuyoutWaitTime;
        uint256 minimumPrice;
    }

    struct buyOutDetails {
        uint256 lastBidPrice;

        //@note: Can pack all of this into one slot 
        uint256 lastBidTime;
        //@note: Bidder address and bool can be packed together to save gas
        address lastBidder;
        bool buyOutStarted;
    }

    mapping(uint256 => tokenIdDetails) public tokeIdsDetailsMapping;

    mapping(uint256 => buyOutDetails) public buyOutDetailsMapping;


    //@note: This will help you to keep track of how much was deposit 
    //@note: Not sending it in the same transaction because of security issues (ddos attack)
    mapping(address => uint256) public depositAmount;

    //@note: If the transfer fails adding it to the claims which can be claimed later by the lastbidder
    mapping(address => uint256[]) private claims;

    constructor(IERC721 _nftAddress) {
        vaultNftAddy = _nftAddress;
    }

    //@todo: Only Controller should call this
    //@param: The tokenId you want to deposit into the vault
    //@param: the fractions you want to divide the nft's into
    function deposit(
        uint256 _tokenId,
        uint256 _fractions,
        uint256 _minimumBuyoutWaitTime,
        uint256 _minimumPrice
    ) external {
        tokeIdsDetailsMapping[_tokenId]
            .minimumBuyoutWaitTime = _minimumBuyoutWaitTime;
        tokeIdsDetailsMapping[_tokenId].minimumPrice = _minimumPrice;

        vaultNftAddy.safeTransferFrom(msg.sender, address(this), _tokenId);
        _mint(msg.sender, _tokenId, _fractions);
    }

    //@todo: Only controller should cal lthis function

    //@todo: Only has to call the first time buyout has started
    //@Need to Call only the first time
    function initiateBuyout(uint256 _tokenId) external {
        //@Directly use here to save an mload
        
        require(
            msg.value > tokeIdsDetailsMapping[_tokenId].minimumPrice,
            "The amount is too low"
        );

        require(!buyOutDetailsMapping[_tokenId].buyOutStarted,
            "Buyout has already initialised");


        //@note: I can directly do sstore instead of sloading it and caching the value to save the gas
        buyOutDetailsMapping[_tokenId].lastBidPrice = msg.value;

        buyOutDetailsMapping[_tokenId].lastBidTime = block.timestamp;

        buyOutDetailsMapping[_tokenId].buyOutStarted = true;

        buyOutDetailsMapping[_tokenId].lastBidder = msg.sender;
    }

    //@todo: Only controller should cal lthis function
    //@note: This will save gas for subsequent bidders

    //@note: Instead of sending directly allow the user to claim from the contract 
    function bidOnNft(uint256 _tokenId) external {
        buyOutDetails memory buyoutCache = buyOutDetailsMapping[_tokenId];

        require(buyoutCache.buyOutStarted, "Buyout hasn't initiated yet");

        require(msg.value > buyoutCache.lastBidPrice, "Minimum Bid amount must be greater than last bid ");

        buyoutCache.lastBidTime = block.timestamp;

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

        require(buyoutCache.buyOutStarted,"Buyout hasn't initialised yet");

        require((buyoutCache.lastBidTime + minimumWaitTime) >= block.timestamp, "Cannot Call end bid now");

         depositAmount[lastDepositor] = depositAmount[lastDepositor] - buyoutCache.lastBidPrice;

        //@note: Freeing the storage slot saves you gas
        delete buyOutDetailsMapping[_tokenId];

        _unsafeBurn(_tokenId,totalSupply(_tokenId));

        //@note: following checks and effect 
        try vaultNftAddy.safeTransferFrom(address(this), lastDepositor, _tokenId){
            //@emit an event here 
        }
        //@note: If the claims fails push it to the claims array mapping 
        catch{
            claims[lastDepositor].push(_tokenId);
        }

    }

    //@note: If you have the entire totalSupply of the issued tokens you can withdraw
    //@audit: _burn will revert if the tokenId holder is not the owner of the entire supply
    function withdraw(uint256 _tokenId) external {

        _burn(msg.sender,_tokenId,totalSupply(_tokenId));

        try vaultNftAddy.safeTransferFrom(address(this), msg.sender, _tokenId){
            //@emit an event here 
        }
        //@note: If the claims fails push it to the claims array mapping 
        catch{
            claims[lastDepositor].push(_tokenId);
        }
    }


    //@note:Extremely unsafe burn 

    //@note: The amount has to be entire supply 
    function _unsafeBurn(uint256 _tokenId,uint256 amount) internal {

        uint256[] memory ids = _asSingletonArray(_tokenId);
        uint256[] memory amounts = _asSingletonArray(amount);

         _beforeTokenTransfer(address(this), address(this), address(0), ids, amounts, "");

            //@note:Extreeeeemely unsafe burn
            delete _balances[_tokenId];


            emit TransferSingle(address(this), address(this), address(0), id, amount);
          _afterTokenTransfer(operator, from, address(0), ids, amounts, "");

    }
}
