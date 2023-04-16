// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";


import "src/vaultFactory.sol";
import "src/Vault.sol";
import "lib/openzeppelin-contracts/contracts/mocks/ERC721Mock.sol";
import "src/ClaimBuyouts.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
contract CounterTest is Test,ERC721Holder {

    Vault vault;
    VaultFactory vaultfactory;
    ERC721Mock erc721Mock;
    claimBuyOuts claimcontract;

    address owner = address(0x69420);
    address depositor = address(0xdee);
    address depositor2 = address(0xffff);
    address bidder1 = address(0xfee);
    address bidder2 = address(0x240);
    address bidEnder = address(0x69420);

    function setUp() public {
        vm.startPrank(owner);

        vaultfactory = new VaultFactory();
        erc721Mock = new ERC721Mock("TestNft","TFT");
        claimcontract = new claimBuyOuts(vaultfactory);
        vaultfactory.updateClaimContract(claimcontract);
        vault = vaultfactory.deployVault(erc721Mock);
        vm.stopPrank();

    }


    function test_depositNft() public {
        vm.startPrank(depositor);

        erc721Mock.mint(depositor, 1);
        erc721Mock.approve(address(vault), 1);
        vault.deposit(1,10,1);
        vm.stopPrank();
    }

    function test_withdrawNft() public {
        test_depositNft();
        vm.startPrank(depositor);
        vault.withdraw(1);
        vm.stopPrank();

    }

    function test_initiateBuyout() public {
        test_depositNft();
        vm.startPrank(bidder1);
        vm.deal(bidder1,100 ether);
        vault.initiateBuyout{value: 15 ether}(1);
        vm.stopPrank();

    }


    function test_bidOnNft() public {
        test_initiateBuyout();
        vm.startPrank(bidder2);
        vm.deal(bidder2,200 ether);
        vault.bidOnNft{value: 16 ether}(1);
        vm.stopPrank();


    }

    function test_endNft() public {
        test_bidOnNft();
        vm.startPrank(bidEnder);
        vm.warp(99999);
        vault.endBid(1);
        vm.stopPrank();
    }

    function test_withdrawPrevious() public {
        test_endNft();
        
        vm.startPrank(bidder1);

        vault.withdrawBidMoney(15 ether);

        vm.stopPrank();

    }


    function test_claimBalance() public {
        test_endNft();
        vm.startPrank(depositor);
        claimcontract.claimBalance(address(erc721Mock),uint256(1));
        vm.stopPrank();
    }

    function test_claimBalance2() public {
        test_endNft();
        vm.startPrank(depositor);
        vault.safeTransferFrom(depositor, depositor2, 1, 5, "");
        vm.stopPrank();
        console.log("1stBalance of depositor2");
        vm.startPrank(depositor2);
        console.log(depositor2.balance);
        claimcontract.claimBalance(address(erc721Mock),uint256(1));
        console.log("2ndBalance of depositor2");
        console.log(depositor2.balance);





    }



}
