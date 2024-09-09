// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle contract
 * @author Vasil Grozdanov
 * @notice This is a sample Raffle contract
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    error Raffle__NotEnoughFunds();
    error Raffle__RaffleNotOpen();
    error Raffle__TransferFailed();
    error Raffle__CallerNotOwner(address caller);
    error Raffle__UpkeepNotNeeded(
        uint256 balance,
        uint256 numberOfPlayers,
        State raffleState
    );

    enum State {
        OPEN,
        CALCULATING
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    /**
     * @dev The interval between raffle wins
     */
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    uint256 private s_subscriptionId;
    address payable[] private s_players;
    address payable private s_recentWinner;
    uint256 private s_lastTimestamp;
    State private s_state;

    event NewRaffleEntrance(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 _entranceFee,
        uint256 _interval,
        address vrfCordinator,
        bytes32 gaslane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCordinator) {
        i_entranceFee = _entranceFee;
        i_interval = _interval;
        s_lastTimestamp = block.timestamp;
        i_keyHash = gaslane;
        s_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_state = State.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughFunds();
        }
        if (s_state != State.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        emit NewRaffleEntrance(msg.sender);
        s_players.push(payable(msg.sender));
    }

    /**
     * @dev This is the function that Chainlink nodes will call to check if the raffle is ready to pick a winner.
     * The following is needed in order for upkeepNeeded to be true:
     * 1. The time interval has passed since the last time a winner was picked
     * 2. The raffle is open
     * 3. The contract has received ETH
     * 4. Implicitly, your subscription has received LINK
     * @param - ignored
     * @return upkeepNeeded - true if the raffle is restarted
     * @return - ignored
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = (block.timestamp - s_lastTimestamp > i_interval);
        bool isOpen = s_state == State.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                s_state
            );
        }

        s_state = State.CALCULATING;
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: s_subscriptionId,
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
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] calldata randomWords
    ) internal virtual override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_state = State.OPEN;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;
        emit WinnerPicked(recentWinner);

        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /**
     *  @notice Getter for the callback gas limit of the VRF
     */
    function getCallbackGasLimit() external view returns (uint32) {
        return i_callbackGasLimit;
    }

    /**
     *  @notice Getter for the subscription id of the VRF
     */
    function getSubscriptionId() external view returns (uint256) {
        return s_subscriptionId;
    }

    /**
     *  @notice Getter for the key hash of the VRF
     */
    function getKeyHash() external view returns (bytes32) {
        return i_keyHash;
    }

    /**
     *  @notice Getter for last timestamp when a winner was picked
     */
    function getLastTimestamp() external view returns (uint256) {
        return s_lastTimestamp;
    }

    /**
     * @notice Getter for the interval between wins in Raffle
     */
    function getInterval() external view returns (uint256) {
        return i_interval;
    }

    /**
     * @notice Getter for entrance fee
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    /**
     * @notice Getter for Raffle state
     */
    function getState() external view returns (State) {
        return s_state;
    }

    /**
     * Get the address of the player at index.
     * @param index - index of player
     */
    function getPlayer(uint256 index) external view returns (address payable) {
        return s_players[index];
    }

    /**
     * @notice Getter for the address of the most recent winner.
     */
    function getRecentWinner() external view returns (address payable) {
        return s_recentWinner;
    }

    /**
     * @notice Getter for the vrf coordinator.
     */
    function getVrfCoordinator() external view returns (address) {
        return address(s_vrfCoordinator);
    }

    /**
     * @notice Sets the new subscription id
     * @param subscriptionId - new subscription id
     */
    function setSubscriptionId(uint256 subscriptionId) external onlyOwner {
        s_subscriptionId = subscriptionId;
    }
}
