// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {BasicNft} from "src/BasicNft.sol";
import {MoodNft} from "src/MoodNft.sol";

contract MintBasicScript is Script {
  string public constant PUB =
    "ipfs://bafybeig37ioir76s7mg5oobetncojcm3c3hxasyd4rvid4jqhy4gkaheg4/?filename=0-PUG.json";

  function run() external {
    address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
      "BasicNft",
      block.chainid
    );
    mintNftOnContract(mostRecentlyDeployed);
  }

  function mintNftOnContract(address contractAddress) public {
    vm.startBroadcast();
    BasicNft(contractAddress).mintNft(PUB);
    vm.stopBroadcast();
  }
}

contract MintMoodNft is Script {
  function run() external {
    address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
      "MoodNft",
      block.chainid
    );
    mintNftOnContract(mostRecentlyDeployed);
  }

  function mintNftOnContract(address contractAddress) public {
    vm.startBroadcast();
    MoodNft(contractAddress).mintNft();
    vm.stopBroadcast();
  }
}
