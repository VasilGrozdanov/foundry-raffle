// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() public {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        if (config.subscriptionId == 0) {
            CreateSubscription subscriptionCreatorContract = new CreateSubscription();
            (
                config.subscriptionId,
                config.vrfCordinator
            ) = subscriptionCreatorContract.createSubscription(
                config.vrfCordinator,
                config.account
            );
            FundSubscription subscriptionFunderContract = new FundSubscription();
            subscriptionFunderContract.fundSubscription(
                config.vrfCordinator,
                config.subscriptionId,
                config.link,
                config.account
            );
            helperConfig.updateConfig(config);
        }
        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCordinator,
            config.gaslane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            config.vrfCordinator,
            config.subscriptionId,
            config.account
        );

        return (raffle, helperConfig);
    }
}
