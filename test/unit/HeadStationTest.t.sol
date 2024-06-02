//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {HeadStation} from "../../src/HeadStation.sol";
import {RateAggregator} from "../../src/RateAggregator.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployHeadStation} from "../../script/DeployHeadStation.s.sol";
import {Test, console} from "forge-std/Test.sol";

contract TestHeadStation is Test {
    HeadStation hs;
    RateAggregator ra;
    HelperConfig helper;
    address ethPriceFeed;
    address weth;
    address USER = address(1);
    address USER2 = address(2);
    uint256 DEPOSITAMOUNT = 10 ether;
    bytes32 collateralType = keccak256("WETH");
    uint256 WITHDRAWAMOUNT = 1 ether;

    function setUp() external {
        DeployHeadStation dhs = new DeployHeadStation();
        (hs, ra, helper) = dhs.run();
        (ethPriceFeed, , weth, , ) = helper.activeNetworkConfig();
    }

    function testDepositCollateral() external {
        vm.startPrank(USER);
        hs.depositCollateral(collateralType, DEPOSITAMOUNT, USER2);
        vm.stopPrank();
        (uint256 collateral, ) = hs.getReserves(collateralType, USER2);
        assertEq(collateral, DEPOSITAMOUNT);
    }

    //1000000000000000000
    function testDepositCollateralMintKSC() external {
        vm.startPrank(USER);
        hs.depositCollateral(collateralType, DEPOSITAMOUNT, USER2);
        hs.withdrawKSC(collateralType, WITHDRAWAMOUNT, USER2);
        vm.stopPrank();
        (uint256 collateral, uint256 debt) = hs.getReserves(
            collateralType,
            USER2
        );
        (uint256 safetyIndex, uint256 stabilityRate) = hs
            .getSafetyIndexOfReserve(collateralType, USER2);
        console.log(safetyIndex, stabilityRate);
        console.log(collateral, debt);
        assertEq(true, debt > 0);
    }
}
