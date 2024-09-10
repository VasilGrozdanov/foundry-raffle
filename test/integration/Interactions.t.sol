// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/Interactions.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract Interactions is Test {
    Raffle public raffle;
    address public PLAYER = makeAddr("Player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;
    address public raffleDeployer;
    HelperConfig public helperConfig;
    HelperConfig.NetworkConfig public networkConfig;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        networkConfig = helperConfig.getConfig();
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    modifier raffleTested() {
        _;

        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffle.getEntranceFee()}();
        assert(payable(address(raffle)).balance == raffle.getEntranceFee());
    }

    function testInteractionsScriptsUsingConfigWorkProperly()
        public
        raffleTested
    {
        CreateSubscription subscriptionCreatorContract = new CreateSubscription();
        (
            uint256 subscriptionId,
            address vrfCoordinator
        ) = subscriptionCreatorContract.createSubscriptionUsingConfig();

        vm.prank(networkConfig.account);
        raffle.setSubscriptionId(subscriptionId);
        vm.prank(networkConfig.account);
        raffle.setCoordinator(vrfCoordinator);

        FundSubscription subscriptionFunderContract = new FundSubscription();
        subscriptionFunderContract.fundSubscriptionUsingConfig(address(raffle));

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumerUsingConfig(address(raffle));
    }
}
