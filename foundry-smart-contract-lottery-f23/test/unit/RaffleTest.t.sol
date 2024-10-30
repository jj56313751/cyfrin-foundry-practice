// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is CodeConstants, Test {
  Raffle public raffle;
  HelperConfig public helperConfig;

  uint256 entranceFee;
  uint256 interval;
  address vrfCoordinator;
  bytes32 gasLane;
  uint256 subscriptionId;
  uint32 callbackGasLimit;

  address public PLAYER = makeAddr("player");
  uint256 public constant STARTING_PLAYING_BALANCE = 10 ether;

  event RaffleEntered(address indexed player);

  function setUp() external {
    DeployRaffle depolyer = new DeployRaffle();
    (raffle, helperConfig) = depolyer.deployContract();
    HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
    entranceFee = config.entranceFee;
    interval = config.interval;
    vrfCoordinator = config.vrfCoordinator;
    gasLane = config.gasLane;
    subscriptionId = config.subscriptionId;
    callbackGasLimit = config.callbackGasLimit;

    vm.deal(PLAYER, STARTING_PLAYING_BALANCE);
  }

  function testRaffleInitializeInOpenState() public view {
    assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
  }

  /* ENTER RAFFLE */
  function testRaffleRevertsWhenYouDontPayEnough() public {
    // Arrange
    vm.prank(PLAYER);
    // Act / Assert
    vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
    raffle.enterRaffle();
  }

  function testRaffleRecordsPlayersWhenTheyEnter() public {
    // Arrange
    vm.prank(PLAYER);
    // Act
    raffle.enterRaffle{value: entranceFee}();
    // Assert
    address playerRecorded = raffle.getPlayer(0);
    assert(playerRecorded == PLAYER);
  }

  function testEnterRaffleEmitsEvent() public {
    // Arrange
    vm.prank(PLAYER);
    // Act
    vm.expectEmit(true, false, false, false, address(raffle));
    emit RaffleEntered(PLAYER);
    // Assert
    raffle.enterRaffle{value: entranceFee}();
  }

  function testDontAllowEnterWhenRaffleIsCalculating() public {
    // Arrange
    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();
    vm.warp(block.timestamp + interval + 1);
    vm.roll(block.number + 1);
    raffle.performUpkeep("");
    // Act /Assert
    vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();
  }

  /* CHECK UPKEEP */
  function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
    // Arrange
    vm.warp(block.timestamp + interval + 1);
    vm.roll(block.number + 1);
    // Act
    (bool upkeepNeeded, ) = raffle.checkUpKeep("");
    // Assert
    assert(!upkeepNeeded);
  }

  function testCheckUpKeepReturnsFalseIfRaffleIsntOpen() public {
    // Arrange
    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();
    vm.warp(block.timestamp + interval + 1);
    vm.roll(block.number + 1);
    raffle.performUpkeep("");
    // Act
    (bool upkeepNeeded, ) = raffle.checkUpKeep("");
    // Assert
    assert(!upkeepNeeded);
  }

  function testCheckUpKeepReturnsFalseIfRaffleHasNoPlayers() public {
    // Arrange
    raffle.enterRaffle{value: entranceFee}();
    vm.warp(block.timestamp + interval + 1);
    vm.roll(block.number + 1);
    raffle.performUpkeep("");
    // Act
    (bool upkeepNeeded, ) = raffle.checkUpKeep("");
    // Assert
    assert(!upkeepNeeded);
  }

  function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
    // Arrange
    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();
    // Act
    (bool upkeepNeeded, ) = raffle.checkUpKeep("");
    // Assert
    assert(!upkeepNeeded);
  }

  function testCheckUpkeepReturnsTrueWhenParametersAreGood() public {
    // Arrange
    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();
    vm.warp(block.timestamp + interval + 1);
    vm.roll(block.number + 1);
    // Act
    (bool upkeepNeeded, ) = raffle.checkUpKeep("");
    // Assert
    assert(upkeepNeeded);
  }

  /* PERFORM UPKEEP */
  function testPerformUpKeepCanOnlyRunIfCheckUpkeepIsTrue() public {
    // Arrange
    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();
    vm.warp(block.timestamp + interval + 1);
    vm.roll(block.number + 1);
    // Act / Assert
    raffle.performUpkeep("");
  }

  function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
    // Arrange
    uint256 currentBalance = 0;
    uint256 numPlayers = 0;
    Raffle.RaffleState raffleState = raffle.getRaffleState();
    // Act / Assert
    vm.expectRevert(
      abi.encodeWithSelector(
        Raffle.Raffle_UpkeepNotNeeded.selector,
        currentBalance,
        numPlayers,
        raffleState
      )
    );
    raffle.performUpkeep("");
  }

  modifier raffleEntered() {
    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();
    vm.warp(block.timestamp + interval + 1);
    vm.roll(block.number + 1);
    _;
  }

  function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
    public
    raffleEntered
  {
    // Arrange
    // Act
    vm.recordLogs();
    raffle.performUpkeep("");
    Vm.Log[] memory entires = vm.getRecordedLogs();
    bytes32 requestId = entires[1].topics[1];
    // Assert
    Raffle.RaffleState raffleState = raffle.getRaffleState();
    assert(uint256(requestId) > 0);
    assert(uint256(raffleState) == 1);
  }

  /* fulfillRandomWords */
  modifier skipFork() {
    if (block.chainid != LOCAL_CHAIN_ID) {
      return;
    }
    _;
  }

  function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
    uint256 randomRequestId
  ) public raffleEntered skipFork {
    // Arrange / Act / Assert
    vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
    VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
      randomRequestId,
      address(raffle)
    );
  }

  function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
    public
    raffleEntered
    skipFork
  {
    // Arrange
    uint256 additionalEntrants = 3;
    uint256 startingIndex = 1;
    address expectedWinner = address(1);

    for (
      uint256 i = startingIndex;
      i <= startingIndex + additionalEntrants;
      i++
    ) {
      address newPlayer = address(uint160(i));
      hoax(newPlayer, 1 ether);
      raffle.enterRaffle{value: entranceFee}();
    }

    uint256 startingTimeStamp = raffle.getLastTimeStamp();
    uint256 winnerStartingBalance = expectedWinner.balance;
    console2.log("[winnerStartingBalance]-246", winnerStartingBalance);

    // Act
    vm.recordLogs();
    raffle.performUpkeep("");
    Vm.Log[] memory entires = vm.getRecordedLogs();
    bytes32 requestId = entires[1].topics[1];

    VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
      uint256(requestId),
      address(raffle)
    );

    // Assert
    address recentWinner = raffle.getRecentWinner();
    Raffle.RaffleState raffleState = raffle.getRaffleState();
    uint256 winnerBalance = recentWinner.balance;
    console2.log("[winnerBalance]-246", winnerBalance);
    uint256 endingTimeStamp = raffle.getLastTimeStamp();
    uint256 prize = entranceFee * (additionalEntrants + 1);
    console2.log("[prize]-246", prize);

    assert(recentWinner == expectedWinner);
    assert(uint256(raffleState) == 0);
    assert(winnerBalance == (winnerStartingBalance + prize + entranceFee));
    assert(endingTimeStamp > startingTimeStamp);
  }
}
