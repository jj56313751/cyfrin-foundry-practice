// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {OurToken} from "src/OurToken.sol";
import {DeployOurToken} from "script/DeployOurToken.s.sol";

contract OurTokenTest is Test {
  OurToken public ourToken;
  DeployOurToken deployer;

  // address owner = vm.addr(1);
  address bob = makeAddr("Bob");
  address alice = makeAddr("Alice");

  uint256 public constant STARTING_BALANCE = 100 ether;

  function setUp() public {
    deployer = new DeployOurToken();
    ourToken = deployer.run();

    vm.prank(msg.sender);
    ourToken.transfer(bob, STARTING_BALANCE);
  }

  function testBobBalacne() public {
    assertEq(ourToken.balanceOf(bob), STARTING_BALANCE);
  }

  function testAllowancesWorks() public {
    uint256 inititalAllowance = 1000;

    // Bob approves Alice to spend tokens on her behalf
    vm.prank(bob);
    ourToken.approve(alice, inititalAllowance);

    uint256 transferAmount = 500;

    vm.prank(alice);
    ourToken.transferFrom(bob, alice, transferAmount);

    assertEq(ourToken.balanceOf(alice), transferAmount);
    assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - transferAmount);
  }

  // function testMint() public {
  //     token.mint(owner, 1000);
  //     assertEq(token.balanceOf(owner), 1000);
  // }

  // function testTransfer() public {
  //     token.mint(owner, 1000);
  // }
} // end of contract
