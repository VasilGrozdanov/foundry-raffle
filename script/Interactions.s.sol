// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Raffle} from "../src/Raffle.sol";

abstract contract MostRecentRaffleFinder {
    function getMostRecentDeployed() public view returns (address) {
        return DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
    }
}

contract CreateSubscription is Script, MostRecentRaffleFinder {
    function createSubscriptionUsingConfig()
        public
        returns (uint256 subId, address vrfCordinator)
    {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig
            .getConfig();
        vrfCordinator = networkConfig.vrfCordinator;
        (subId, vrfCordinator) = createSubscription(
            vrfCordinator,
            networkConfig.account
        );
        networkConfig.subscriptionId = subId;
        return (subId, vrfCordinator);
    }

    function createSubscription(
        address vrfCordinator,
        address account
    ) public returns (uint256 subId, address) {
        console2.log("Creating subscription on chain Id: ", block.chainid);
        vm.startBroadcast(account);
        subId = VRFCoordinatorV2_5Mock(vrfCordinator).createSubscription();
        vm.stopBroadcast();

        console2.log("Your subscription id is: ", subId);
        console2.log("vrfCordinator: ", vrfCordinator);
        console2.log("Please update your subscription id in the HelperConfig ");
        return (subId, vrfCordinator);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants, MostRecentRaffleFinder {
    uint256 public constant FUND_AMOUNT = 3 ether; // 3 LINK

    function fundSubscriptionUsingConfig(address lastDeployedContract) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCordinator = helperConfig.getConfig().vrfCordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        if (subscriptionId == 0) {
            Raffle raffle = Raffle(lastDeployedContract);
            subscriptionId = raffle.getSubscriptionId();
            vrfCordinator = raffle.getVrfCoordinator();
        }
        address linkToken = helperConfig.getConfig().link;

        fundSubscription(
            vrfCordinator,
            subscriptionId,
            linkToken,
            helperConfig.getConfig().account
        );
    }

    function fundSubscription(
        address vrfCordinator,
        uint256 subscriptionId,
        address linkToken,
        address account
    ) public {
        console2.log("Funding subscription on chain Id: ", block.chainid);
        console2.log("Your subscription id is: ", subscriptionId);
        console2.log("vrfCoordinator: ", vrfCordinator);
        vm.startBroadcast(account);
        if (block.chainid == LOCAL_CHAIN_ID) {
            VRFCoordinatorV2_5Mock(vrfCordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT
            );
        } else {
            LinkToken(linkToken).transferAndCall(
                vrfCordinator,
                FUND_AMOUNT,
                abi.encode(subscriptionId)
            );
        }
        vm.stopBroadcast();
    }

    function run() public {
        fundSubscriptionUsingConfig(getMostRecentDeployed());
    }
}

contract AddConsumer is Script, CodeConstants, MostRecentRaffleFinder {
    function addConsumerUsingConfig(address contractToAddToVrf) public {
        HelperConfig helperConfig = new HelperConfig();
        Raffle lastDeployed = Raffle(contractToAddToVrf);
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address vrfCordinator = lastDeployed.getVrfCoordinator();
        if (subscriptionId == 0) {
            subscriptionId = lastDeployed.getSubscriptionId();
        }
        addConsumer(
            contractToAddToVrf,
            vrfCordinator,
            subscriptionId,
            helperConfig.getConfig().account
        );
    }

    function addConsumer(
        address contractToAddToVrf,
        address vrfCordinator,
        uint256 subscriptionId,
        address account
    ) public {
        console2.log("Adding consumer contract: ", contractToAddToVrf);
        console2.log("vrfCordinator: ", vrfCordinator);
        console2.log("subscriptionId: ", subscriptionId);
        console2.log("chainId: ", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCordinator).addConsumer(
            subscriptionId,
            contractToAddToVrf
        );
        vm.stopBroadcast();
    }

    function run() external {
        addConsumerUsingConfig(getMostRecentDeployed());
    }
}
