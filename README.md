# NeonLedger Smart Contract

A decentralized carbon credit verification and trading system built on the Stacks blockchain. This smart contract enables transparent verification of carbon offset projects and manages the issuance of verifiable carbon credits.

## Overview

CarbonCredit facilitates the verification and trading of carbon offset credits by providing a trustless system where authorized validators can verify carbon offset projects and issue credits to offsetters. The contract ensures transparency and accountability in the carbon credit market.

## Key Features

### 🌱 Carbon Offset Verification
- Apply for verification of carbon offset projects
- Minimum offset threshold of 50 tonnes CO2 equivalent
- Support for various offset methods (reforestation, renewable energy, etc.)

### 👥 Validator Management
- Admin-controlled validator authorization system
- Multiple validators can verify different projects
- Validator removal and management capabilities

### 🔍 Verification Process
- Two-step verification process (application → validation)
- Immutable verification records on blockchain
- Revocation system with justification tracking

### 💰 Cost Management
- Configurable verification costs (default: 2000 microstacks)
- Admin-controlled fee structure
- Maximum limits to prevent abuse

## Contract Architecture

### Core Data Structures

#### Offsetter Data
```clarity
{
    total-offset: uint,           // Total CO2 offset in tonnes
    last-verification-date: uint, // Block height of last verification
    offset-method: string,        // Method used for carbon offset
    verification-status: bool,    // Current verification status
    revocation-justification: optional string, // Reason for revocation
    revocation-date: optional uint,           // When revoked
    revoked-by: optional principal            // Who revoked
}
```

## Main Functions

### Public Functions

#### `apply-for-verification(offset-amount, offset-method)`
Apply for carbon credit verification with offset details.

**Parameters:**
- `offset-amount`: Amount of CO2 offset (minimum 50 tonnes)
- `offset-method`: Description of offset method (max 20 chars)

#### `verify-offsetter(offsetter)`
Verify an offsetter's carbon credit application (validators only).

**Parameters:**
- `offsetter`: Principal address of the offsetter to verify

#### `revoke-verification(offsetter, justification)`
Revoke verification with justification (admin/validators only).

**Parameters:**
- `offsetter`: Principal address of the offsetter
- `justification`: Reason for revocation (max 50 chars)

#### `add-validator(validator)` / `remove-validator(validator)`
Manage authorized validators (admin only).

#### `set-verification-cost(new-cost)` / `set-minimum-offset(new-threshold)`
Update contract parameters (admin only).

### Read-Only Functions

#### `is-verified(offsetter)` → `bool`
Check if an offsetter is currently verified.

#### `get-offsetter-data(offsetter)` → `offsetter-data`
Retrieve complete offsetter information including revocation history.

#### `get-verification-cost()` → `uint`
Get current verification cost in microstacks.

## Usage Examples

### 1. Applying for Verification
```clarity
;; Apply for verification of 100 tonnes CO2 offset through reforestation
(contract-call? .carbon-credit apply-for-verification u100 "reforestation")
```

### 2. Checking Verification Status
```clarity
;; Check if an address is verified
(contract-call? .carbon-credit is-verified 'SP1ABC...)
```

### 3. Validator Operations
```clarity
;; Verify an offsetter (as authorized validator)
(contract-call? .carbon-credit verify-offsetter 'SP1ABC...)

;; Revoke verification with justification
(contract-call? .carbon-credit revoke-verification 'SP1ABC... "Invalid documentation")
```

## Error Codes

- `u300`: Admin-only function
- `u301`: Offsetter not verified
- `u302`: Already verified
- `u303`: Invalid validator
- `u304`: Invalid offset amount
- `u305`: Not permitted to perform action
- `u306`: Invalid cost parameter
- `u307`: Invalid threshold parameter
- `u308`: Invalid description
- `u309`: Invalid justification

## Security Features

- **Admin Controls**: Critical functions restricted to contract admin
- **Validator Authorization**: Only approved validators can verify projects
- **Input Validation**: All parameters validated for security
- **Revocation Tracking**: Complete audit trail for revoked verifications
- **Rate Limiting**: Maximum offset limits prevent abuse

## Deployment

Deploy using Clarinet or Stacks CLI:

```bash
clarinet deploy --network testnet
```

## Testing

Run the test suite:

```bash
clarinet test
```

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## Support

For questions or issues, please open a GitHub issue.