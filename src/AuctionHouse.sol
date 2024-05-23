//SPDX-License-Identifier: MIT

/**
 * @title AuctionHouse
 * @author Karthikeya Gundumogula
 * @dev The Liquidation contract calls this contract to execute auctions
 */
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceFeedLib} from "./libraries/PriceFeedLib.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IRateAggregator {
    function currentAuctionPrice(
        uint256 initialPrice,
        uint256 timeElapsed
    ) external view returns (uint256 price);
}

interface IHeadStation {
    function addKeeperIncentives(
        address _keeper,
        uint _amount,
        bytes32 _collateralId
    ) external;
    function withdrawCollateral(
        bytes32 _collateralType,
        uint256 _amount,
        address _user
    ) external;
    function depositKSC(
        bytes32 _collateralId,
        uint256 _amount,
        address _user
    ) external ;
}
interface IKelCoinTeller {
     function depositKelCoin(
        address _user,
        uint _amount,
        bytes32 _collateralType
    ) external ;
}

contract AuctionHouse is ReentrancyGuard {
    error AuctionHouseError_UnAuthorizedOperation();
    error AuctionHouseError_TooExpensive();
    error AuctionHouseError_NeedRestart();
    error AuctionHouseError_CannotRestartAuction();
    error AuctionHouseError_AuctionsOwnerFlow(bytes32 collateralId);
    error AuctionHouseError_InvalidParameter();
    error AuctionHouseError_UnRecognizedCollateral();
    error AuctionHouseError_UnRecognizedOperation();

    struct Auction {
        bytes32 collateralId;
        uint256 auctionPosition;
        uint256 kscToRaise;
        uint256 collateralAmountOnAuction;
        address reserveOwner;
        uint96 auctionStartTime;
        uint256 initialPrice;
    }
    struct Collateral {
        uint256 intialIncrement; // Multiplicative factor to increase starting price                  [ray]
        uint256 thresholdTime; // Time elapsed before auction reset                                 [seconds]
        uint256 thresholdPrice; // Percentage drop before auction reset                              [ray]
        uint64 keeperIncentive; // Percentage of kscToRaise to suck from vow to incentivize keepers         [wad]
        uint192 keeperFlatFee; // Flat fee to suck from vow to incentivize keepers                  [rad]
        address priceFeed;
        address collateral_tokenAddress;
    }

    using PriceFeedLib for AggregatorV3Interface;

    IRateAggregator private s_rateAggregator;
    IHeadStation private s_headStation;
    IKelCoinTeller private s_kscTeller;
    uint256 private s_totalAuctions;
    mapping(bytes32 collateralId => Collateral collateral)
        private s_collaterals;
    mapping(bytes32 collateralId => uint256[] auctionIds)
        private s_collateralActiveAuctionIds;
    mapping(uint256 auctionId => Auction auction) private s_auctions;
    mapping(address user => bool) private s_authorizedAddresses;

    //--Events--//
    event authorizedAddressAdded(address indexed usr);
    event authorizedAddressRemoved(address indexed usr);

    event collateralParametersUpdated(
        bytes32 indexed what,
        bytes32 indexed collateralId,
        uint256 data
    );
    event priceFeedUpdated(bytes32 indexed collateralId, address data);

    event auctionStarted(
        uint256 auctionId,
        bytes32 indexed collateralId,
        uint256 initialPrice,
        uint256 totalDebt,
        uint256 collateralAmount,
        address indexed reserveOwner,
        address indexed keeper,
        uint256 extras
    );
    event sold(
        uint256 indexed auctionId,
        bytes32 indexed collateralId,
        uint256 maxKSC,
        uint256 price,
        uint256 soldAmount,
        uint256 totalDebt,
        uint256 totalCollateral,
        address indexed reserveOwner
    );
    event auctionRestarted(
        uint256 indexed auctionID,
        uint256 initialPrice,
        uint256 totalDebt,
        uint256 totalCollateral,
        address indexed reserveOwner,
        address indexed keeper,
        uint256 extras
    );

    event Yank(uint256 id);

    constructor(address _rateAggregator, address _headStation,address _kelCoinTeller) {
        s_rateAggregator = IRateAggregator(_rateAggregator);
        s_headStation = IHeadStation(_headStation);
        s_authorizedAddresses[msg.sender] = true;
        s_kscTeller= IKelCoinTeller(_kelCoinTeller);
    }

    //--Authorization and Administration--//
    modifier authenticate() {
        if (!s_authorizedAddresses[msg.sender]) {
            revert AuctionHouseError_UnAuthorizedOperation();
        }
        _;
    }

    function addAuthorizedAddress(address _user) external authenticate {
        s_authorizedAddresses[_user] = true;
        emit authorizedAddressAdded(_user);
    }

    function removeAuthorizedAddress(address _user) external authenticate {
        s_authorizedAddresses[_user] = false;
        emit authorizedAddressRemoved(_user);
    }

    function updateCollateralParams(
        bytes32 _collateralId,
        bytes32 _feild,
        uint256 _value
    ) external authenticate {
        if (_feild == "initialIncrement") {
            s_collaterals[_collateralId].intialIncrement = _value;
        } else if (_feild == "thresholdTime") {
            s_collaterals[_collateralId].thresholdTime = _value;
        } else if (_feild == "thresholdPrice") {
            s_collaterals[_collateralId].thresholdPrice = _value;
        } else if (_feild == "keeperIncentive") {
            s_collaterals[_collateralId].keeperIncentive = uint64(_value);
        } else if (_feild == "keeperTip") {
            s_collaterals[_collateralId].keeperFlatFee = uint192(_value);
        } else {
            revert AuctionHouseError_UnRecognizedOperation();
        }
        emit collateralParametersUpdated(_feild, _collateralId, _value);
    }

    function updateCollateralAddresses(
        bytes32 _collateralId,
        bytes32 _feild,
        address _value
    ) external authenticate {
        if (_feild == "priceFeed") {
            s_collaterals[_collateralId].priceFeed = _value;
        } else if (_feild == "tokenAddress") {
            s_collaterals[_collateralId].collateral_tokenAddress = _value;
        }else {
            revert AuctionHouseError_UnRecognizedOperation();
        }
        emit priceFeedUpdated(_collateralId, _value);
    }

    function updateAddresses(
        bytes32 _feild,
        address _value
    ) external authenticate {
        if (_feild == "rateAggregator") {
            s_rateAggregator = IRateAggregator(_value);
        } else if (_feild == "headStation") {
            s_headStation = IHeadStation(_value);
        } else {
            revert AuctionHouseError_UnRecognizedOperation();
        }
    }

    function startAuction(
        bytes32 _collateralId,
        uint256 _collateralAmount,
        uint256 _debtAmount,
        address _reserveOwner,
        address _keeper
    ) external authenticate nonReentrant {
        if (s_collaterals[_collateralId].intialIncrement == 0) {
            revert AuctionHouseError_UnRecognizedCollateral();
        }
        if (
            _collateralAmount == 0 ||
            _debtAmount == 0 ||
            _reserveOwner == address(0)
        ) {
            revert AuctionHouseError_InvalidParameter();
        }
        uint256 id = ++s_totalAuctions;
        if (id < 0) {
            revert AuctionHouseError_AuctionsOwnerFlow(_collateralId);
        }
        s_collateralActiveAuctionIds[_collateralId].push(id);
        s_auctions[id].auctionPosition =
            s_collateralActiveAuctionIds[_collateralId].length -
            1;
        s_auctions[id].auctionStartTime = uint96(block.timestamp);
        s_auctions[id].collateralId = _collateralId;
        s_auctions[id].collateralAmountOnAuction = _collateralAmount;
        int256 tokenPrice = _getPriceOfCollateralInUSD(
            s_collaterals[_collateralId].priceFeed
        );
        s_auctions[id].initialPrice = _rmul(
            uint256(tokenPrice),
            s_collaterals[_collateralId].intialIncrement
        );
        uint256 flatfee = s_collaterals[_collateralId].keeperFlatFee;
        uint256 incentives = s_collaterals[_collateralId].keeperIncentive;
        uint256 extraFee;
        if (flatfee > 0 && incentives > 0) {
            extraFee = _add(flatfee, _wmul(_debtAmount, incentives));
            s_headStation.addKeeperIncentives(_keeper, extraFee, _collateralId);
        }
        s_auctions[id].kscToRaise = _add(_debtAmount, extraFee);
        emit auctionStarted(
            id,
            _collateralId,
            s_auctions[id].initialPrice,
            s_auctions[id].kscToRaise,
            _collateralAmount,
            _reserveOwner,
            _keeper,
            extraFee
        );
    }

    function restartAuction(
        uint256 _auctionId,
        address _keeper
    ) external nonReentrant {
        address reserveOwner = s_auctions[_auctionId].reserveOwner;
        uint96 auctionStartTime = s_auctions[_auctionId].auctionStartTime;
        uint256 initialPrice = s_auctions[_auctionId].initialPrice;
        bytes32 collateralId = s_auctions[_auctionId].collateralId;
        uint256 totalDebt = s_auctions[_auctionId].kscToRaise;
        uint256 totalCollateral = s_auctions[_auctionId]
            .collateralAmountOnAuction;

        if (reserveOwner == address(0)) {
            revert AuctionHouseError_InvalidParameter();
        }
        (bool done, ) = status(
            auctionStartTime,
            initialPrice,
            s_collaterals[collateralId].thresholdTime,
            s_collaterals[collateralId].thresholdPrice
        );
        if (!done) {
            revert AuctionHouseError_CannotRestartAuction();
        }
        s_auctions[_auctionId].auctionStartTime = uint96(block.timestamp);
        address feed = s_collaterals[collateralId].priceFeed;
        int256 feedPrice = _getPriceOfCollateralInUSD(feed);
        initialPrice = _rmul(
            uint(feedPrice),
            s_collaterals[collateralId].intialIncrement
        );
        require(initialPrice > 0, "Clipper/zero-top-price");
        s_auctions[_auctionId].initialPrice = initialPrice;

        // incentive to redo auction
        uint256 flatFee = s_collaterals[collateralId].keeperFlatFee;
        uint256 keeperIncentives = s_collaterals[collateralId].keeperIncentive;
        uint256 coin;
        if (flatFee > 0 || keeperIncentives > 0) {
            coin = _add(flatFee, _wmul(totalDebt, keeperIncentives));
            s_headStation.addKeeperIncentives(_keeper, coin, collateralId);
        }

        emit auctionRestarted(
            _auctionId,
            initialPrice,
            totalDebt,
            totalCollateral,
            reserveOwner,
            _keeper,
            coin
        );
    }

    function buy(
        uint256 _auctionId, // Auction id
        uint256 _maxCollateral, // Upper limit on amount of collateral to buy  [wad]
        uint256 _max, // Maximum acceptable price (DAI / collateral) [ray]
        address _receiver // Receiver of collateral and external call address
    ) external nonReentrant {
        address reserveOwner = s_auctions[_auctionId].reserveOwner;
        uint96 auctionStartTime = s_auctions[_auctionId].auctionStartTime;
        bytes32 collateralId = s_auctions[_auctionId].collateralId;

        uint256 price;
        {
            bool done;
            (done, price) = status(
                auctionStartTime,
                s_auctions[_auctionId].initialPrice,
                s_collaterals[collateralId].thresholdTime,
                s_collaterals[collateralId].thresholdPrice
            );
            if (done) {
                revert AuctionHouseError_NeedRestart();
            }
        }
        if (_max < price) {
            revert AuctionHouseError_TooExpensive();
        }
        uint256 totalCollateral = s_auctions[_auctionId]
            .collateralAmountOnAuction;
        uint256 totalDebt = s_auctions[_auctionId].kscToRaise;
        uint256 owe;

        {
            uint256 slice = _min(totalCollateral, _maxCollateral); // slice <= lot
            owe = _mul(slice, price);
            if (owe > totalDebt) {
                owe = totalDebt;
                slice = owe / price;
            } else if (owe < totalDebt && slice < totalCollateral) {
                slice = owe / price;
            }
            totalDebt = totalDebt - owe;
            totalCollateral = totalCollateral - slice;

            // Send collateral to who
            s_headStation.withdrawCollateral(collateralId,slice,_receiver);
            // Get DAI from caller
            s_kscTeller.depositKelCoin(msg.sender,owe,collateralId);
            // Removes Dai out for liquidation from accumulator
            // dog_.digs(ilk, totalCollateral == 0 ? totalDebt + owe : owe);
        }

        if (totalCollateral == 0) {
            _remove(_auctionId, collateralId);
        } else if (totalDebt == 0) {
            // vat.flux(ilk, address(this), reserveOwner, totalCollateral);
            _remove(_auctionId, collateralId);
        } else {
            s_auctions[_auctionId].kscToRaise = totalDebt;
            s_auctions[_auctionId].collateralAmountOnAuction = totalCollateral;
        }

        emit sold(
            _auctionId,
            collateralId,
            _max,
            price,
            owe,
            totalDebt,
            totalCollateral,
            reserveOwner
        );
    }

    //--Internal Helper Functions--//
    function _remove(uint256 _auctionId, bytes32 _collateralId) internal {
        uint256 pos = s_auctions[_auctionId].auctionPosition;
        uint256[] storage active = s_collateralActiveAuctionIds[_collateralId];
        uint256 x = active[active.length - 1];
        if (_auctionId != x) {
            active[pos] = x;
            s_auctions[x].auctionPosition = pos;
        }
        active.pop();
        delete s_auctions[_auctionId];
    }

    function status(
        uint96 _auctionStartTime,
        uint256 _initialPrice,
        uint256 _thresholdTime,
        uint256 _thresholdPrice
    ) internal view returns (bool done, uint256 price) {
        price = s_rateAggregator.currentAuctionPrice(
            _initialPrice,
            _sub(block.timestamp, _auctionStartTime)
        );
        done = (_sub(block.timestamp, _auctionStartTime) > _thresholdTime ||
            _rdiv(price, _initialPrice) < _thresholdPrice);
    }

    function _getPriceOfCollateralInUSD(
        address _feed
    ) internal view returns (int256 value) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_feed);
        (, value, , , ) = priceFeed.staleCheckLatestRoundData();
    }

    // --- Math ---
    uint256 constant BLN = 10 ** 9;
    uint256 constant TOKEN_PRECISION = 10 ** 18;
    uint256 constant PRECISON = 10 ** 27;

    function _min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x <= y ? x : y;
    }

    function _add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }

    function _sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }

    function _mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function _wmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = _mul(x, y) / TOKEN_PRECISION;
    }

    function _rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = _mul(x, y) / PRECISON;
    }

    function _rdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = _mul(x, PRECISON) / y;
    }
}
