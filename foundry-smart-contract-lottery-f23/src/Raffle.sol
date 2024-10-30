// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle Contract
 * @author Shane Wang
 * @notice
 */
contract Raffle is VRFConsumerBaseV2Plus {
  /* Errors */
  error Raffle__SendMoreToEnterRaffle();
  error Raffle__TransferFailed();
  error Raffle__RaffleNotOpen();
  error Raffle_UpkeepNotNeeded(
    uint256 balance,
    uint256 playersLength,
    uint256 raffleState
  );

  /* Type Declarations */
  enum RaffleState {
    OPEN,
    CALCULATING
  }

  /* State Variables */
  uint16 private constant REQUEST_CONFIRMATIONS = 3;
  uint32 private constant NUM_WORDS = 1;
  uint256 private immutable i_entranceFee;
  // The duration of the lottery in seconds
  uint256 private immutable i_interval;
  bytes32 private immutable i_keyHash;
  uint256 private immutable i_subscriptionId;
  uint32 private immutable i_callbackGasLimit;
  address payable[] private s_players;
  uint256 private s_lastTimeStamp;
  address private s_recentWinner;
  RaffleState private s_raffleState;

  /** Events */
  event RaffleEntered(address indexed player);
  event WinnerPicked(address indexed player);
  event RequestedRaffleWinner(uint256 indexed requrestId);

  constructor(
    uint256 entranceFee,
    uint256 interval,
    address vrfCoordinator,
    bytes32 gasLane,
    uint256 subscriptionId,
    uint32 callbackGasLimit
  ) VRFConsumerBaseV2Plus(vrfCoordinator) {
    i_entranceFee = entranceFee;
    i_interval = interval;
    i_keyHash = gasLane;
    i_subscriptionId = subscriptionId;
    i_callbackGasLimit = callbackGasLimit;
    s_lastTimeStamp = block.timestamp;
    // s_vrfCoordinator.requestRandomWords();
    s_raffleState = RaffleState.OPEN;
  }

  function enterRaffle() public payable {
    // require(msg.value >= i_entranceFee, "Not enough ETH!");
    if (msg.value < i_entranceFee) {
      revert Raffle__SendMoreToEnterRaffle();
    }

    if (s_raffleState != RaffleState.OPEN) {
      revert Raffle__RaffleNotOpen();
    }

    s_players.push(payable(msg.sender));

    emit RaffleEntered(msg.sender);
  }

  // automation chainlink (upkeep) https://docs.chain.link/chainlink-automation/guides/compatible-contracts
  // When should the winner be picked?
  /**
   * @dev This is the function that the Chainlink VRF node will call to see
   * if the lottery is ready to have a winner picked.
   * The following should be true in order for upkeep to be true:
   * 1. The time interval has passed between raffle runs.
   * 2. The lottery is open.
   * 3. The contract has ETH (has players).
   * 4. Implicity, your subscription has LINK.
   * @param - ignored
   * @return upkeepNeeded - true if it is time to restart the lottery
   * @return -ignored
   */
  function checkUpKeep(
    bytes memory /* checkData */
  ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
    bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
    bool isOpen = s_raffleState == RaffleState.OPEN;
    bool hasBalance = address(this).balance > 0;
    bool hasPlayers = s_players.length > 0;

    upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;

    return (upkeepNeeded, "0x0");
  }

  function performUpkeep(bytes calldata /* performData */) external {
    // check to see if enough time has passed
    // if (block.timestamp - s_lastTimeStamp < i_interval) {
    //   revert();
    // }
    (bool upkeepNeeded, ) = checkUpKeep("");
    if (!upkeepNeeded) {
      revert Raffle_UpkeepNotNeeded(
        address(this).balance,
        s_players.length,
        uint256(s_raffleState)
      );
    }
    s_raffleState = RaffleState.CALCULATING;

    // https://docs.chain.link/vrf/v2-5/subscription/get-a-random-number#analyzing-the-contract
    VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
      .RandomWordsRequest({
        keyHash: i_keyHash,
        subId: i_subscriptionId,
        requestConfirmations: REQUEST_CONFIRMATIONS,
        callbackGasLimit: i_callbackGasLimit,
        numWords: NUM_WORDS,
        extraArgs: VRFV2PlusClient._argsToBytes(
          // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
          VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
        )
      });
      
    uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

    emit RequestedRaffleWinner(requestId);
    // s_vrfCoordinator.requestRandomWords(request);
  }

  // CEI: Checks, Effects, Interactions patten
  function fulfillRandomWords(
    uint256 /* requestId */,
    uint256[] calldata randomWords
  ) internal override {
    // checks

    // effects (Inernal Contract State)
    uint256 indexOfWinner = randomWords[0] % s_players.length;
    address payable recentWinner = s_players[indexOfWinner];
    s_recentWinner = recentWinner;

    s_raffleState = RaffleState.OPEN;
    s_players = new address payable[](0);
    s_lastTimeStamp = block.timestamp;
    emit WinnerPicked(s_recentWinner);

    // interactions (External Contract Ineractions)
    (bool success, ) = recentWinner.call{value: address(this).balance}("");
    if (!success) {
      revert Raffle__TransferFailed();
    }
  }

  /**
   * Getter Functions
   */
  function getEntranceFee() external view returns (uint256) {
    return i_entranceFee;
  }

  function getRaffleState() external view returns (RaffleState) {
    return s_raffleState;
  }

  function getPlayer(uint256 indexOfPlayer) external view returns (address) {
    return s_players[indexOfPlayer];
  }

  function getLastTimeStamp() external view returns(uint256) {
    return s_lastTimeStamp;
  }

  function getRecentWinner() external view returns(address) {
    return s_recentWinner;
  }
}
