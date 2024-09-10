// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    int256 public constant MOCK_WEI_PER_UINT_LINK = 4e18;

    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCordinator;
        bytes32 gaslane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        address account;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaConfig();
    }

    function updateConfig(NetworkConfig memory _networkConfig) external {
        localNetworkConfig = _networkConfig;
        networkConfigs[block.chainid] = _networkConfig;
    }

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.1 ether,
                interval: 30,
                vrfCordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                gaslane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                subscriptionId: 0, // change if you have subscription already and want to deploy with scripts
                callbackGasLimit: 500000,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                account: 0x3b195607a32C41bD613d48BAb5a9a7761022D4C3
            });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (networkConfigs[LOCAL_CHAIN_ID].vrfCordinator != address(0)) {
            return localNetworkConfig;
        }
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinator = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UINT_LINK
        );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.1 ether,
            interval: 30,
            vrfCordinator: address(vrfCoordinator),
            gaslane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            link: address(linkToken),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });
        return localNetworkConfig;
    }
}
