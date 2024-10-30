// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
  /* VRF Mock Values */
  uint96 public MOCK_BASE_FEE = 0.25 ether;
  uint96 public MOCK_GAS_PRICE = 1e9;
  int256 public MOCK_WEI_PER_UNIT_LINK = 4e15;

  uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
  uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {
  error HelperConfig__InvalidChainId();

  struct NetworkConfig {
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    address link;
    address account;
  }

  NetworkConfig public localNetworkConfig;
  mapping(uint256 => NetworkConfig) public networkConfigs;

  constructor() {
    networkConfigs[11155111] = getSepoliaEthConfig();
  }

  function getConfigByChainId(
    uint256 chainId
  ) public returns (NetworkConfig memory) {
    if (networkConfigs[chainId].vrfCoordinator != address(0)) {
      return networkConfigs[chainId];
    } else if (chainId == LOCAL_CHAIN_ID) {
      return getOrCreateAnvilEthConfig();
    } else {
      revert HelperConfig__InvalidChainId();
    }
  }

  function getConfig() public returns (NetworkConfig memory) {
    return getConfigByChainId(block.chainid);
  }

  function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
    return
      NetworkConfig({
        entranceFee: 0.01 ether,
        interval: 30, // 30 seconds
        // https://docs.chain.link/vrf/v2-5/supported-networks
        vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
        gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
        // https://vrf.chain.link/ => My Subscriptions
        subscriptionId: 8139124529664716148959176063451670572276330374873296790418668637568339788081,
        callbackGasLimit: 500000, // 500,000 gas
        link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
        account: 0x2a42fd00F3e2d19D446960d1F247544D6911b77e
      });
  }

  function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
    // check to see if we set an active work config
    if (localNetworkConfig.vrfCoordinator != address(0)) {
      return localNetworkConfig;
    }
    // Deploy mocks and such
    vm.startBroadcast();
    VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
      MOCK_BASE_FEE,
      MOCK_GAS_PRICE,
      MOCK_WEI_PER_UNIT_LINK
    );
    LinkToken linkToken = new LinkToken();

    vm.stopBroadcast();

    localNetworkConfig = NetworkConfig({
      entranceFee: 0.01 ether,
      interval: 30, // 30 seconds
      // https://docs.chain.link/vrf/v2-5/supported-networks
      vrfCoordinator: address(vrfCoordinatorMock),
      gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
      subscriptionId: 0,
      callbackGasLimit: 500000, // 500,000 gas
      link: address(linkToken),
      // /lib/forge-std/src/Base.sol -> DEFAULT_SENDER
      account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
    });

    return localNetworkConfig;
  }
}