//SPDX-License-Identifier: MIT

/**
 * @title RateAggregator
 * @author Karthikeya Gundumogula
 * @notice This contract calculates the stability rate for the given collateral
 */

pragma solidity ^0.8.20;

contract RateAggregator {
    error RateAggregatorError_UnAuthorizedOperation();
    error RateAggregatorError_InvalidCollateral();
    error RateAggregatorError_CollateralAlreadyInitialized();
    error RateAggregatorError_StationNotLive();

    struct Collateral {
        uint256 stabilityFee;
        uint256 lastUpdate;
    }

    uint256 public constant PRECISION = 10e27;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 10e10;
    uint256 private constant DECIMAL_PRECISION = 10e18;
    uint256 public s_baseStabilityFee; //protocol level
    mapping(bytes32 collateralType => Collateral data)
        public s_collateralTokens;
    mapping(address user => bool authorized) public s_authorizedAddresses;

    //--Events--//
    event StatusUpdated(bool status);
    event AuthorizedAddressAdded(address user);
    event AuthorizedAddressRemoved(address user);

    constructor() {
        s_authorizedAddresses[msg.sender] = true;
    }

    //--Authorization & Administration--//
    modifier authenticate() {
        if (s_authorizedAddresses[msg.sender] != true) {
            revert RateAggregatorError_UnAuthorizedOperation();
        }
        _;
    }

    function addAuthorizedAddress(address _user) external authenticate {
        s_authorizedAddresses[_user] = true;
        emit AuthorizedAddressAdded(_user);
    }

    function removeAuthorizedAddress(address _user) external authenticate {
        s_authorizedAddresses[_user] = false;
        emit AuthorizedAddressRemoved(_user);
    }

    function updateBaseStabilityFee(uint256 _newValue) external authenticate {
        s_baseStabilityFee = _newValue;
    }

    function initNewCollateralType(
        bytes32 _collateralId,
        uint256 _stabilityFee
    ) external authenticate {
        if (s_collateralTokens[_collateralId].stabilityFee != 0) {
            revert RateAggregatorError_CollateralAlreadyInitialized();
        }
        s_collateralTokens[_collateralId].stabilityFee =
            _stabilityFee *
            PRECISION;
        s_collateralTokens[_collateralId].lastUpdate = block.timestamp;
    }

    function calculateStabilityRate(
        bytes32 _collateralId,
        uint256 _oldRate
    ) external returns (uint256 newRate) {
        if (block.timestamp <= s_collateralTokens[_collateralId].lastUpdate) {
            return newRate = _oldRate;
        }
        newRate = _rmul(
            _rpow(
                _add(
                    s_baseStabilityFee,
                    s_collateralTokens[_collateralId].stabilityFee
                ),
                block.timestamp - s_collateralTokens[_collateralId].lastUpdate,
                PRECISION
            ),
            _oldRate
        );
        s_collateralTokens[_collateralId].lastUpdate = block.timestamp;
    }

    // --- Math ---
    function _rpow(uint x, uint n, uint b) internal pure returns (uint z) {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    z := b
                }
                default {
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    z := b
                }
                default {
                    z := x
                }
                let half := div(b, 2) // for rounding.
                for {
                    n := div(n, 2)
                } n {
                    n := div(n, 2)
                } {
                    let xx := mul(x, x)
                    if iszero(eq(div(xx, x), x)) {
                        revert(0, 0)
                    }
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) {
                        revert(0, 0)
                    }
                    x := div(xxRound, b)
                    if mod(n, 2) {
                        let zx := mul(z, x)
                        if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) {
                            revert(0, 0)
                        }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) {
                            revert(0, 0)
                        }
                        z := div(zxRound, b)
                    }
                }
            }
        }
    }

    function _add(uint x, uint y) internal pure returns (uint z) {
        z = x + y;
        require(z >= x);
    }

    function _diff(uint x, uint y) internal pure returns (int z) {
        z = int(x) - int(y);
        require(int(x) >= 0 && int(y) >= 0);
    }

    function _rmul(uint x, uint y) internal pure returns (uint z) {
        z = x * y;
        require(y == 0 || z / y == x);
        z = z / PRECISION;
    }
}
