// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/Interactions.s.sol";

contract Interactions is Test {
    Raffle public raffle;
    address public PLAYER = makeAddr("Player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;
    address public raffleDeployer;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        raffleDeployer = address(deployer);
        (raffle, ) = deployer.deployContract();
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

        vm.prank(raffle.owner());
        raffle.setSubscriptionId(subscriptionId);
        vm.prank(raffle.owner());
        raffle.setCoordinator(vrfCoordinator);

        FundSubscription subscriptionFunderContract = new FundSubscription();
        subscriptionFunderContract.fundSubscriptionUsingConfig(address(raffle));

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumerUsingConfig(address(raffle));
    }
}
