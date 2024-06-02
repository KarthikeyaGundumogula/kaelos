//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {HeadStation} from "../src/HeadStation.sol";
import {RateAggregator} from "../src/RateAggregator.sol";

contract DeployHeadStation is Script {
    function run()
        external
        returns (HeadStation, RateAggregator, HelperConfig)
    {
        bytes32 collateralType = keccak256("WETH");
        address USER = address(1);
        RateAggregator ra = new RateAggregator();
        ra.updateBaseStabilityFee(1);
        ra.initNewCollateralType(collateralType, 1);
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        (address wethUsdPriceFeed, , , , ) = helperConfig.activeNetworkConfig();
        vm.startBroadcast();
        HeadStation hs = new HeadStation(address(ra));
        hs.initializeCollateralToken(collateralType, wethUsdPriceFeed);
        hs.updateCollateralToken(
            collateralType,
            "upperLimit",
            1000 ether
        );
        hs.updateCollateralToken(
            collateralType,
            "lowerLimit",
            1 wei
        );
        hs.updateCollateralToken(
            collateralType,
            "liquidationThreshold",
            50
        );
        hs.updateCollateralToken(collateralType, "stabilityFee", 1);
        hs.addAuthorizedAddress(USER);
        vm.stopBroadcast();

        return (hs, ra, helperConfig);
    }
}
