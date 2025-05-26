# Tokenized Decentralized Derivatives Platform

A comprehensive blockchain-based derivatives trading ecosystem that tokenizes financial derivatives as NFTs while providing automated risk management, margin tracking, and settlement execution through interconnected smart contracts.

## 🎯 Platform Overview

The Tokenized Decentralized Derivatives Platform transforms traditional derivatives trading by creating a fully decentralized, transparent, and automated trading environment. Each derivative contract is minted as a unique NFT, enabling secondary market trading while maintaining complete on-chain settlement and risk management.

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Oracle Price Feeds                       │
│              (Chainlink, Band Protocol)                     │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌─────────────────┐    │    ┌─────────────────┐    ┌─────────────────┐
│ Asset           │◄───┼───►│ Contract        │◄──►│ Margin          │
│ Verification    │    │    │ Specification   │    │ Management      │
│ Contract        │    │    │ Contract        │    │ Contract        │
└─────────────────┘    │    └─────────────────┘    └─────────────────┘
         │              │             │                        │
         │              │             └────────────────────────┼─────┐
         │              │                                      │     │
         └──────────────┼──────────────────────────────────────┘     │
                        │                                            │
         ┌──────────────▼────────────────────────────────────────────▼─┐
         │                Settlement Protocol                          │
         │                   Contract                                  │
         └──────────────┬────────────────────────────────────────────┬─┘
                        │                                            │
         ┌──────────────▼────────────────────────────────────────────▼─┐
         │                Risk Management                              │
         │                   Contract                                  │
         └─────────────────────────────────────────────────────────────┘
```

## 📋 Core Smart Contracts

### 1. Asset Verification Contract
**Purpose**: Validates underlying instruments and maintains price feed integrity

**Key Features**:
- Multi-oracle price aggregation and validation
- Asset whitelisting and blacklisting mechanisms
- Historical price data storage and validation
- Price manipulation detection algorithms
- Real-time asset health monitoring
- Cross-reference validation with external sources

**Core Functions**:
```solidity
interface IAssetVerification {
    function verifyAsset(address asset) external returns (bool);
    function addPriceFeed(address asset, address priceFeed) external;
    function getValidatedPrice(address asset) external view returns (uint256 price, uint256 timestamp);
    function isAssetSupported(address asset) external view returns (bool);
    function blacklistAsset(address asset, string memory reason) external;
    function detectPriceManipulation(address asset) external view returns (bool);
}
```

**Price Validation Logic**:
```solidity
contract AssetVerification {
    struct AssetData {
        address[] priceFeeds;
        uint256 lastValidPrice;
        uint256 lastUpdateTime;
        bool isActive;
        uint256 deviationThreshold;
    }
    
    mapping(address => AssetData) public assets;
    uint256 public constant MAX_PRICE_DEVIATION = 500; // 5%
    uint256 public constant STALE_PRICE_THRESHOLD = 3600; // 1 hour
    
    function validatePrice(address asset) internal view returns (uint256) {
        AssetData memory assetData = assets[asset];
        require(assetData.isActive, "Asset not supported");
        
        uint256[] memory prices = new uint256[](assetData.priceFeeds.length);
        uint256 validPrices = 0;
        
        for (uint i = 0; i < assetData.priceFeeds.length; i++) {
            try AggregatorV3Interface(assetData.priceFeeds[i]).latestRoundData() 
                returns (uint80, int256 price, uint256, uint256 updatedAt, uint80) {
                if (price > 0 && block.timestamp - updatedAt < STALE_PRICE_THRESHOLD) {
                    prices[validPrices] = uint256(price);
                    validPrices++;
                }
            } catch {}
        }
        
        require(validPrices >= 2, "Insufficient valid price feeds");
        return calculateMedianPrice(prices, validPrices);
    }
}
```

### 2. Contract Specification Contract (ERC-721)
**Purpose**: Defines derivative parameters and mints tokenized contracts

**Supported Derivative Types**:
- **European/American Options** (Call/Put)
- **Futures Contracts** (Physical/Cash Settlement)
- **Interest Rate Swaps** (Fixed/Floating)
- **Currency Swaps** (Multi-currency)
- **Exotic Options** (Barrier, Asian, Binary)
- **Structured Products** (Custom payoffs)

**Contract Structure**:
```solidity
contract DerivativeNFT is ERC721, AccessControl {
    enum DerivativeType { CALL_OPTION, PUT_OPTION, FUTURES, SWAP, EXOTIC }
    enum SettlementType { CASH, PHYSICAL }
    enum ExerciseType { EUROPEAN, AMERICAN, BERMUDAN }
    
    struct DerivativeSpec {
        DerivativeType contractType;
        address underlyingAsset;
        uint256 strikePrice;
        uint256 notionalAmount;
        uint256 expirationTime;
        SettlementType settlementType;
        ExerciseType exerciseType;
        address creator;
        address counterparty;
        uint256 premium;
        bytes customParameters;
        ContractStatus status;
    }
    
    mapping(uint256 => DerivativeSpec) public derivatives;
    uint256 private _tokenIdCounter;
    
    function createDerivative(
        DerivativeType _type,
        address _underlying,
        uint256 _strike,
        uint256 _notional,
        uint256 _expiration,
        bytes memory _customParams
    ) external returns (uint256 tokenId) {
        require(assetVerification.isAssetSupported(_underlying), "Asset not supported");
        
        tokenId = _tokenIdCounter++;
        
        derivatives[tokenId] = DerivativeSpec({
            contractType: _type,
            underlyingAsset: _underlying,
            strikePrice: _strike,
            notionalAmount: _notional,
            expirationTime: _expiration,
            settlementType: SettlementType.CASH,
            exerciseType: ExerciseType.EUROPEAN,
            creator: msg.sender,
            counterparty: address(0),
            premium: 0,
            customParameters: _customParams,
            status: ContractStatus.ACTIVE
        });
        
        _safeMint(msg.sender, tokenId);
        emit DerivativeCreated(tokenId, _type, _underlying, _strike, _expiration);
    }
}
```

**Exotic Derivatives Support**:
```solidity
// Barrier Options
struct BarrierParams {
    uint256 barrierLevel;
    bool isKnockIn;    // true for knock-in, false for knock-out
    bool isUpBarrier;  // true for up-and-out/in, false for down-and-out/in
}

// Asian Options
struct AsianParams {
    uint256[] observationDates;
    bool isArithmetic;  // true for arithmetic average, false for geometric
}

// Binary Options
struct BinaryParams {
    uint256 payoutAmount;
    bool isAssetOrNothing;  // true for asset-or-nothing, false for cash-or-nothing
}
```

### 3. Margin Management Contract
**Purpose**: Automated collateral tracking and margin requirement calculations

**Margin System Features**:
- **Cross-margining**: Portfolio-level margin optimization
- **Multi-collateral**: Support for various ERC-20 tokens
- **Dynamic calculations**: Real-time margin requirements
- **Liquidation protection**: Automated position management
- **Yield generation**: Integration with lending protocols

**Core Implementation**:
```solidity
contract MarginManager {
    struct MarginAccount {
        mapping(address => uint256) collateralBalances;  // token => amount
        mapping(address => uint256) collateralFactors;   // token => haircut factor
        uint256 totalRequiredMargin;
        uint256 totalMaintenanceMargin;
        bool crossMarginEnabled;
        uint256[] activePositions;  // NFT token IDs
    }
    
    mapping(address => MarginAccount) public accounts;
    mapping(address => uint256) public tokenHaircuts;  // Collateral haircut factors
    
    uint256 public constant MAINTENANCE_RATIO = 1250;  // 125% maintenance margin
    uint256 public constant INITIAL_RATIO = 1500;     // 150% initial margin
    uint256 public constant BASIS_POINTS = 10000;
    
    function depositCollateral(address token, uint256 amount) external {
        require(amount > 0, "Invalid amount");
        require(tokenHaircuts[token] > 0, "Token not accepted as collateral");
        
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        accounts[msg.sender].collateralBalances[token] += amount;
        
        emit CollateralDeposited(msg.sender, token, amount);
        _updateMarginStatus(msg.sender);
    }
    
    function calculateRequiredMargin(address user) public view returns (uint256 required, uint256 maintenance) {
        MarginAccount storage account = accounts[user];
        
        for (uint i = 0; i < account.activePositions.length; i++) {
            uint256 tokenId = account.activePositions[i];
            DerivativeSpec memory spec = derivativeNFT.getDerivativeSpec(tokenId);
            
            (uint256 positionRequired, uint256 positionMaintenance) = _calculatePositionMargin(spec);
            required += positionRequired;
            maintenance += positionMaintenance;
        }
        
        // Apply cross-margin benefits if enabled
        if (account.crossMarginEnabled && account.activePositions.length > 1) {
            uint256 diversificationBenefit = _calculateDiversificationBenefit(user);
            required = required * (BASIS_POINTS - diversificationBenefit) / BASIS_POINTS;
            maintenance = maintenance * (BASIS_POINTS - diversificationBenefit) / BASIS_POINTS;
        }
    }
    
    function _calculatePositionMargin(DerivativeSpec memory spec) internal view returns (uint256 required, uint256 maintenance) {
        uint256 currentPrice = assetVerification.getValidatedPrice(spec.underlyingAsset);
        uint256 volatility = _getImpliedVolatility(spec.underlyingAsset);
        uint256 timeToExpiry = spec.expirationTime > block.timestamp ? 
            spec.expirationTime - block.timestamp : 0;
        
        if (spec.contractType == DerivativeType.CALL_OPTION || spec.contractType == DerivativeType.PUT_OPTION) {
            // Black-Scholes based margin calculation
            required = _calculateOptionMargin(spec, currentPrice, volatility, timeToExpiry);
            maintenance = required * MAINTENANCE_RATIO / BASIS_POINTS;
        } else if (spec.contractType == DerivativeType.FUTURES) {
            // Futures margin based on notional value and volatility
            required = spec.notionalAmount * volatility * sqrt(timeToExpiry) / (365 * 24 * 3600);
            maintenance = required * MAINTENANCE_RATIO / BASIS_POINTS;
        }
    }
}
```

**Liquidation Engine**:
```solidity
contract LiquidationEngine {
    event LiquidationTriggered(address indexed user, uint256 indexed tokenId, uint256 liquidationValue);
    
    function checkLiquidation(address user) external view returns (bool canLiquidate, uint256[] memory positionsToLiquidate) {
        uint256 totalCollateralValue = marginManager.getTotalCollateralValue(user);
        (uint256 requiredMargin, uint256 maintenanceMargin) = marginManager.calculateRequiredMargin(user);
        
        if (totalCollateralValue < maintenanceMargin) {
            canLiquidate = true;
            positionsToLiquidate = _selectPositionsForLiquidation(user, maintenanceMargin - totalCollateralValue);
        }
    }
    
    function liquidatePosition(address user, uint256 tokenId) external {
        require(hasRole(LIQUIDATOR_ROLE, msg.sender), "Not authorized liquidator");
        
        (bool canLiquidate,) = checkLiquidation(user);
        require(canLiquidate, "Position not eligible for liquidation");
        
        uint256 liquidationValue = _calculateLiquidationValue(tokenId);
        uint256 liquidationPenalty = liquidationValue * LIQUIDATION_PENALTY / BASIS_POINTS;
        
        // Execute liquidation
        _executeLiquidation(user, tokenId, liquidationValue, liquidationPenalty);
    }
}
```

### 4. Settlement Protocol Contract
**Purpose**: Handles automated contract execution and settlement

**Settlement Types**:
- **Automatic Settlement**: Oracle-triggered at expiration
- **Manual Exercise**: User-initiated for American options
- **Cash Settlement**: Monetary difference payment
- **Physical Settlement**: Actual asset delivery (future implementation)
- **Early Settlement**: Pre-expiration closure

**Implementation**:
```solidity
contract SettlementProtocol {
    enum SettlementStatus { PENDING, IN_PROGRESS, COMPLETED, FAILED, DISPUTED }
    
    struct Settlement {
        uint256 tokenId;
        uint256 settlementPrice;
        uint256 settlementValue;
        SettlementStatus status;
        uint256 settlementTimestamp;
        address initiator;
        bytes settlementData;
    }
    
    mapping(uint256 => Settlement) public settlements;
    mapping(address => bool) public automatedSettlers;  // Keepers/bots
    
    modifier onlyValidContract(uint256 tokenId) {
        require(derivativeNFT.exists(tokenId), "Contract does not exist");
        DerivativeSpec memory spec = derivativeNFT.getDerivativeSpec(tokenId);
        require(spec.status == ContractStatus.ACTIVE, "Contract not active");
        _;
    }
    
    function settleContract(uint256 tokenId) external onlyValidContract(tokenId) {
        DerivativeSpec memory spec = derivativeNFT.getDerivativeSpec(tokenId);
        require(block.timestamp >= spec.expirationTime, "Contract not expired");
        
        uint256 settlementPrice = assetVerification.getValidatedPrice(spec.underlyingAsset);
        uint256 settlementValue = _calculateSettlementValue(spec, settlementPrice);
        
        settlements[tokenId] = Settlement({
            tokenId: tokenId,
            settlementPrice: settlementPrice,
            settlementValue: settlementValue,
            status: SettlementStatus.IN_PROGRESS,
            settlementTimestamp: block.timestamp,
            initiator: msg.sender,
            settlementData: ""
        });
        
        _executeSettlement(tokenId, settlementValue);
    }
    
    function exerciseOption(uint256 tokenId) external onlyValidContract(tokenId) {
        DerivativeSpec memory spec = derivativeNFT.getDerivativeSpec(tokenId);
        require(spec.contractType == DerivativeType.CALL_OPTION || spec.contractType == DerivativeType.PUT_OPTION, "Not an option");
        require(spec.exerciseType == ExerciseType.AMERICAN || block.timestamp >= spec.expirationTime, "Cannot exercise yet");
        require(derivativeNFT.ownerOf(tokenId) == msg.sender, "Not option owner");
        
        uint256 currentPrice = assetVerification.getValidatedPrice(spec.underlyingAsset);
        uint256 exerciseValue = _calculateExerciseValue(spec, currentPrice);
        
        require(exerciseValue > 0, "Option out of the money");
        
        _executeEarlyExercise(tokenId, exerciseValue);
    }
    
    function _calculateSettlementValue(DerivativeSpec memory spec, uint256 currentPrice) internal pure returns (uint256) {
        if (spec.contractType == DerivativeType.CALL_OPTION) {
            return currentPrice > spec.strikePrice ? 
                (currentPrice - spec.strikePrice) * spec.notionalAmount / 1e18 : 0;
        } else if (spec.contractType == DerivativeType.PUT_OPTION) {
            return spec.strikePrice > currentPrice ? 
                (spec.strikePrice - currentPrice) * spec.notionalAmount / 1e18 : 0;
        } else if (spec.contractType == DerivativeType.FUTURES) {
            // Futures settlement: difference between current price and strike
            return currentPrice > spec.strikePrice ?
                (currentPrice - spec.strikePrice) * spec.notionalAmount / 1e18 :
                (spec.strikePrice - currentPrice) * spec.notionalAmount / 1e18;
        }
        return 0;
    }
    
    function batchSettle(uint256[] memory tokenIds) external {
        for (uint i = 0; i < tokenIds.length; i++) {
            try this.settleContract(tokenIds[i]) {
                // Settlement successful
            } catch {
                // Log failed settlement, continue with others
                emit SettlementFailed(tokenIds[i], "Batch settlement failed");
            }
        }
    }
}
```

### 5. Risk Management Contract
**Purpose**: System-wide risk monitoring and exposure control

**Risk Metrics Calculated**:
- **Portfolio Greeks**: Delta, Gamma, Theta, Vega, Rho
- **Value at Risk (VaR)**: 95% and 99% confidence levels
- **Expected Shortfall**: Average loss beyond VaR
- **Stress Testing**: Scenario-based loss calculations
- **Concentration Risk**: Single asset/counterparty exposure

**Implementation**:
```solidity
contract RiskManager {
    struct RiskMetrics {
        int256 portfolioDelta;      // Price sensitivity
        uint256 portfolioGamma;     // Delta sensitivity  
        int256 portfolioTheta;      // Time decay
        uint256 portfolioVega;      // Volatility sensitivity
        int256 portfolioRho;        // Interest rate sensitivity
        uint256 valueAtRisk95;      // 95% VaR
        uint256 valueAtRisk99;      // 99% VaR
        uint256 expectedShortfall;  // Conditional VaR
    }
    
    mapping(address => RiskMetrics) public userRiskMetrics;
    mapping(address => uint256) public positionLimits;
    mapping(address => bool) public riskManagers;
    
    uint256 public systemVaR;
    uint256 public maxSingleAssetExposure = 2000; // 20% of system
    bool public circuitBreakerTriggered;
    
    function calculatePortfolioRisk(address user) external returns (RiskMetrics memory) {
        uint256[] memory positions = marginManager.getUserPositions(user);
        
        RiskMetrics memory metrics;
        
        for (uint i = 0; i < positions.length; i++) {
            uint256 tokenId = positions[i];
            DerivativeSpec memory spec = derivativeNFT.getDerivativeSpec(tokenId);
            
            // Calculate Greeks for each position
            (int256 delta, uint256 gamma, int256 theta, uint256 vega, int256 rho) = 
                _calculatePositionGreeks(spec);
            
            metrics.portfolioDelta += delta;
            metrics.portfolioGamma += gamma;
            metrics.portfolioTheta += theta;
            metrics.portfolioVega += vega;
            metrics.portfolioRho += rho;
        }
        
        // Calculate VaR using Monte Carlo simulation
        metrics.valueAtRisk95 = _calculateVaR(user, 95);
        metrics.valueAtRisk99 = _calculateVaR(user, 99);
        metrics.expectedShortfall = _calculateExpectedShortfall(user);
        
        userRiskMetrics[user] = metrics;
        return metrics;
    }
    
    function _calculatePositionGreeks(DerivativeSpec memory spec) internal view returns (
        int256 delta, uint256 gamma, int256 theta, uint256 vega, int256 rho
    ) {
        uint256 currentPrice = assetVerification.getValidatedPrice(spec.underlyingAsset);
        uint256 volatility = _getImpliedVolatility(spec.underlyingAsset);
        uint256 timeToExpiry = spec.expirationTime - block.timestamp;
        uint256 riskFreeRate = _getRiskFreeRate();
        
        if (spec.contractType == DerivativeType.CALL_OPTION) {
            delta = int256(_calculateCallDelta(currentPrice, spec.strikePrice, timeToExpiry, volatility, riskFreeRate));
            gamma = _calculateGamma(currentPrice, spec.strikePrice, timeToExpiry, volatility, riskFreeRate);
            theta = -int256(_calculateTheta(currentPrice, spec.strikePrice, timeToExpiry, volatility, riskFreeRate));
            vega = _calculateVega(currentPrice, spec.strikePrice, timeToExpiry, volatility, riskFreeRate);
            rho = int256(_calculateCallRho(currentPrice, spec.strikePrice, timeToExpiry, volatility, riskFreeRate));
        } else if (spec.contractType == DerivativeType.PUT_OPTION) {
            delta = int256(_calculatePutDelta(currentPrice, spec.strikePrice, timeToExpiry, volatility, riskFreeRate));
            gamma = _calculateGamma(currentPrice, spec.strikePrice, timeToExpiry, volatility, riskFreeRate);
            theta = -int256(_calculateTheta(currentPrice, spec.strikePrice, timeToExpiry, volatility, riskFreeRate));
            vega = _calculateVega(currentPrice, spec.strikePrice, timeToExpiry, volatility, riskFreeRate);
            rho = -int256(_calculatePutRho(currentPrice, spec.strikePrice, timeToExpiry, volatility, riskFreeRate));
        }
        
        // Scale by notional amount
        delta = delta * int256(spec.notionalAmount) / 1e18;
        gamma = gamma * spec.notionalAmount / 1e18;
        theta = theta * int256(spec.notionalAmount) / 1e18;
        vega = vega * spec.notionalAmount / 1e18;
        rho = rho * int256(spec.notionalAmount) / 1e18;
    }
    
    function performStressTest(bytes memory scenario) external view returns (uint256 potentialLoss) {
        // Decode stress test scenario
        (int256 priceShock, uint256 volatilityShock, int256 rateShock) = 
            abi.decode(scenario, (int256, uint256, int256));
        
        // Apply shocks to all positions and calculate portfolio impact
        // This is a simplified version - production would use Monte Carlo
        uint256 totalSystemExposure = _getTotalSystemExposure();
        
        // Estimate loss based on system delta and price shock
        int256 systemDelta = _getSystemDelta();
        potentialLoss = uint256(abs(systemDelta * priceShock / 1e18));
        
        // Add volatility impact
        uint256 systemVega = _getSystemVega();
        potentialLoss += systemVega * volatilityShock / 1e18;
    }
    
    function triggerCircuitBreaker(string memory reason) external {
        require(riskManagers[msg.sender], "Not authorized");
        circuitBreakerTriggered = true;
        
        // Pause new position creation
        derivativeNFT.pause();
        marginManager.pause();
        
        emit CircuitBreakerTriggered(msg.sender, reason, block.timestamp);
    }
}
```

## 🚀 Quick Start Guide

### Installation & Setup

```bash
# Clone repository
git clone https://github.com/your-org/tokenized-derivatives-platform.git
cd tokenized-derivatives-platform

# Install dependencies
npm install

# Set up environment
cp .env.example .env
# Edit .env with your configuration

# Compile contracts
npx hardhat compile

# Run tests
npx hardhat test

# Deploy to testnet
npx hardhat run scripts/deploy.js --network goerli
```

### Environment Configuration
```env
# Network Configuration
PRIVATE_KEY=your_private_key
INFURA_API_KEY=your_infura_api_key
ETHERSCAN_API_KEY=your_etherscan_api_key

# Oracle Configuration  
CHAINLINK_ETH_USD=0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
CHAINLINK_BTC_USD=0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c

# Risk Parameters
INITIAL_MARGIN_RATIO=1500        # 150%
MAINTENANCE_MARGIN_RATIO=1250    # 125%  
LIQUIDATION_PENALTY=1000         # 10%
MAX_SINGLE_ASSET_EXPOSURE=2000   # 20%
```

## 💻 Usage Examples

### Creating a Tokenized Derivative

```javascript
const DerivativeNFT = await ethers.getContractFactory("DerivativeNFT");
const derivativeContract = await DerivativeNFT.attach(DERIVATIVE_CONTRACT_ADDRESS);

// Create ETH Call Option
const tx = await derivativeContract.createDerivative(
    0, // CALL_OPTION
    "0x0000000000000000000000000000000000000000", // ETH address
    ethers.utils.parseEther("3000"), // Strike: $3000
    ethers.utils.parseEther("10"),   // Notional: 10 ETH
    Math.floor(Date.now() / 1000) + (30 * 24 * 3600), // 30 days expiry
    "0x" // No custom parameters
);

const receipt = await tx.wait();
const tokenId = receipt.events[0].args.tokenId;
console.log(`Created derivative NFT with ID: ${tokenId}`);
```

### Managing Margin

```javascript
const MarginManager = await ethers.getContractFactory("MarginManager");
const marginContract = await MarginManager.attach(MARGIN_CONTRACT_ADDRESS);

// Deposit USDC collateral
await marginContract.depositCollateral(
    USDC_ADDRESS,
    ethers.utils.parseUnits("5000", 6) // $5000 USDC
);

// Check margin status
const [required, maintenance] = await marginContract.calculateRequiredMargin(userAddress);
console.log(`Required: ${ethers.utils.formatEther(required)} ETH`);
console.log(`Maintenance: ${ethers.utils.formatEther(maintenance)} ETH`);

// Enable cross-margining
await marginContract.enableCrossMargin(true);
```

### Settlement and Exercise

```javascript
const SettlementProtocol = await ethers.getContractFactory("SettlementProtocol");
const settlementContract = await SettlementProtocol.attach(SETTLEMENT_CONTRACT_ADDRESS);

// Exercise American option early
await settlementContract.exerciseOption(tokenId);

// Automatic settlement at expiration
await settlementContract.settleContract(tokenId);

// Batch settlement for multiple contracts
await settlementContract.batchSettle([tokenId1, tokenId2, tokenId3]);
```

### Risk Monitoring

```javascript
const RiskManager = await ethers.getContractFactory("RiskManager");
const riskContract = await RiskManager.attach(RISK_CONTRACT_ADDRESS);

// Calculate portfolio risk metrics
const riskMetrics = await riskContract.calculatePortfolioRisk(userAddress);
console.log(`Portfolio Delta: ${riskMetrics.portfolioDelta}`);
console.log(`95% VaR: ${ethers.utils.formatEther(riskMetrics.valueAtRisk95)} ETH`);

// Perform stress test
const scenario = ethers.utils.defaultAbiCoder.encode(
    ["int256", "uint256", "int256"],
    [-2000, 150, 50] // -20% price, +50% vol, +0.5% rates
);
const stressLoss = await riskContract.performStressTest(scenario);
console.log(`Stress test loss: ${ethers.utils.formatEther(stressLoss)} ETH`);
```

## 🔧 Advanced Features

### Custom Derivative Creation

```solidity
// Exotic option with barrier
bytes memory barrierParams = abi.encode(
    BarrierParams({
        barrierLevel: ethers.utils.parseEther("2800"), // $2800 barrier
        isKnockIn: false,    // Knock-out option
        isUpBarrier: false   // Down-and-out
    })
);

uint256 exoticTokenId = await derivativeContract.createDerivative(
    4, // EXOTIC type
    ETH_ADDRESS,
    ethers.utils.parseEther("3000"), // Strike
    ethers.utils.parseEther("5"),    // Notional
    expirationTime,
    barrierParams
);
```

### Portfolio Risk Dashboard

```javascript
class RiskDashboard {
    constructor(contracts) {
        this.riskContract = contracts.riskManager;
        this.marginContract = contracts.marginManager;
    }
    
    async getPortfolioSummary(userAddress) {
        const [riskMetrics, marginStatus] = await Promise.all([
            this.riskContract.calculatePortfolioRisk(userAddress),
            this.getMarginStatus(userAddress)
        ]);
        
        return {
            totalExposure: marginStatus.totalCollateralValue,
            netDelta: riskMetrics.portfolioDelta,
            gamma: riskMetrics.portfolioGamma,
            theta: riskMetrics.portfolioTheta,
            vega: riskMetrics.portfolioVega,
            var95: riskMetrics.valueAtRisk95,
            marginRatio: marginStatus.marginRatio,
            positions: await this.getActivePositions(userAddress)
        };
    }
    
    async getActivePositions(userAddress) {
        const positions = await this.marginContract.getUserPositions(userAddress);
        return Promise.all(positions.map(async (tokenId) => {
            const spec = await this.derivativeContract.getDerivativeSpec(tokenId);
            const currentPrice = await this.assetContract.getValidatedPrice(spec.underlyingAsset);
            
            return {
                tokenId,
                type: spec.contractType,
                underlying: spec.underlyingAsset,
                strike: spec.strikePrice,
                expiry: spec.expirationTime,
                currentPrice,
                intrinsicValue: this.calculateIntrinsicValue(spec, currentPrice),
                timeValue: this.calculateTimeValue(spec, currentPrice)
            };
        }));
    }
}
