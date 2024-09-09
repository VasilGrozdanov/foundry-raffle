// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;
    HelperConfig.NetworkConfig public networkConfig;
    address public PLAYER = makeAddr("Player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event NewRaffleEntrance(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        networkConfig = helperConfig.getConfig();
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    modifier playerSends() {
        vm.prank(PLAYER);
        _;
    }
    modifier raffleEnded() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: networkConfig.entranceFee}();
        vm.warp(networkConfig.interval + block.timestamp + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testRaffleInitializesProperly() public {
        assert(raffle.getEntranceFee() == networkConfig.entranceFee);
        assert(raffle.getInterval() == networkConfig.interval);
        assert(raffle.getLastTimestamp() == block.timestamp);
        assert(raffle.getKeyHash() == networkConfig.gaslane);
        assert(raffle.getSubscriptionId() == networkConfig.subscriptionId);
        assert(raffle.getCallbackGasLimit() == networkConfig.callbackGasLimit);
        assert(raffle.getState() == Raffle.State.OPEN);
    }

    function testRaffleEntranceRevertsIfUnderEntranceFee() public playerSends {
        vm.expectRevert(Raffle.Raffle__NotEnoughFunds.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public playerSends {
        raffle.enterRaffle{value: networkConfig.entranceFee}();
        assert(PLAYER == raffle.getPlayer(0));
    }

    function testRaffleEmitsEventOnNewPlayerEntrance() public playerSends {
        vm.expectEmit(true, false, false, false, address(raffle));
        emit NewRaffleEntrance(PLAYER);
        raffle.enterRaffle{value: networkConfig.entranceFee}();
    }

    function testEntrancePossibleOnlyWhenRaffleIsOpen() public raffleEnded {
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: networkConfig.entranceFee}();
    }

    function testCheckUpkeepReturnsFalseIfHasNoBalance() public {
        vm.warp(networkConfig.interval + block.timestamp + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfNotOpen() public raffleEnded {
        raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfNotEnoughTimeHasPassed()
        public
        raffleEnded
    {
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenConditionsAreMet()
        public
        playerSends
    {
        raffle.enterRaffle{value: networkConfig.entranceFee}();

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testPerformUpkeepRevertsWhenNotNeeded() public playerSends {
        raffle.enterRaffle{value: networkConfig.entranceFee}();
        uint256 currentBalance = networkConfig.entranceFee;
        uint256 numberOfPlayers = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numberOfPlayers,
                Raffle.State.OPEN
            )
        );
        raffle.performUpkeep("");
    }

    function testPerfomUpkeepRunsOnlyWhenNeeded() public raffleEnded {
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnded
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];
        assert(requestId > 0);
        assert(raffle.getState() == Raffle.State.CALCULATING);
    }

    modifier skipFork() {
        if (block.chainid == LOCAL_CHAIN_ID) {
            _;
        }
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnded skipFork {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(networkConfig.vrfCordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEnded
        skipFork
    {
        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1;

        for (
            uint i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address currentEntrant = address(uint160(i));
            hoax(currentEntrant, STARTING_PLAYER_BALANCE);
            raffle.enterRaffle{value: networkConfig.entranceFee}();
        }
        uint256 playerBalance = PLAYER.balance;
        uint256 startingTimestamp = raffle.getLastTimestamp();

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(networkConfig.vrfCordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        uint256 rafflePrize = networkConfig.entranceFee *
            (additionalEntrants + 1);
        assert(raffle.getState() == Raffle.State.OPEN);
        assert(payable(address(raffle)).balance == 0);
        assert(raffle.getRecentWinner().balance == playerBalance + rafflePrize);
        assert(raffle.getLastTimestamp() > startingTimestamp);
    }
}
