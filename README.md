# SeaFloorFinance: Aptos Move Smart Contract
# Overview
The SeaFloorFinance Project is a decentralized investment pool on the Aptos blockchain. It includes a native token (CRAB), an epoch-based profit distribution system, and a liquidity pool for USDC investments.

# Key Features:
- CRAB Token: Mint, transfer, and burn CRAB tokens.
- Investment Pool: Invest and withdraw USDC, receive CRAB tokens as a stake.
- Epoch Tracking: Manage time-based events like profit distributions.

# Quick Links
Transaction Explorer: View Contract on Aptos Explorer
https://explorer.aptoslabs.com/txn/0xbb7c51564c3431545531d966c904c4ad726632560787755cc713c36b6b281bae/userTxnOverview?network=devnet

Compile & Deploy
Prerequisites
Ensure you have Aptos CLI installed.

Steps to Compile:
Clone the repository or download the contract files.

Run the following command to compile the smart contract:

```
aptos move compile
```

Ensure your Move.toml and source files are correctly set up.

Deploy:
After compiling, deploy the contract using:
```
aptos move publish --package-dir <path-to-your-package> --profile devnet
```
# Sequence Diagram
![image](https://github.com/user-attachments/assets/9ae56425-0d74-40f9-910a-72a7edbfe567)
