# 🎟️ Chainlink-Powered Raffle Smart Contract

This is a decentralized raffle (lottery) smart contract built on Solidity, utilizing Chainlink VRF 2.5 for generating random numbers and Chainlink Automation to automatically execute functions, ensuring a trustless and secure raffle system.

## 🚀 Features
- **🌐 Decentralized and trustless**: No need to trust a centralized entity to run the raffle.
- **🔒 Randomness with Chainlink VRF**: Uses Chainlink’s Verifiable Random Function (VRF) to pick a winner in a provably fair and tamper-proof manner.
- **🤖 Automation with Chainlink Automation**: Automatically closes the raffle and picks a winner at a pre-specified interval.

## 📋 Prerequisites
- Solidity `0.8.19`
- [Foundry](https://book.getfoundry.sh/)
- [GNU Make](https://www.gnu.org/software/make/#download)

## 📜 Contract Overview
### `Raffle.sol`
The main raffle contract where users can participate in the raffle by sending ETH. After a set interval, the Chainlink VRF selects a random winner.

### Key functions:
- **`enterRaffle`**: Allows users to enter the raffle by sending a fixed amount of ETH.
- **`checkUpkeep`**: Part of the Chainlink Automation checks if conditions are met to perform upkeep (such as picking a winner).
- **`performUpkeep`**: Chainlink Automation function that picks the winner using Chainlink VRF.
- **`fulfillRandomWords`**: Receives the random number from Chainlink VRF and determines the raffle winner.

## 🧠 How It Works

1. **🎟️ Users Enter the Raffle**:
   - Participants enter the raffle by sending a fixed amount of ETH to the contract.
   - Their address is recorded in a list of participants.

2. **🎲 Chainlink VRF Generates Random Number**:
   - Once the conditions are met (after a certain time and available participants), the contract requests a random number from Chainlink VRF.
   - The randomness request is fulfilled, and a random winner is selected from the list of participants.

3. **⚙️ Chainlink Automation Closes the Raffle**:
   - The Chainlink Automation service checks whether the raffle is ready to close (when the time interval passes) and automatically triggers the VRF request to pick a winner.

4. **🏆 Winner Receives the Prize**:
   - The ETH collected from the raffle is automatically transferred to the winner’s address.

## 🛠️ Installation

### Clone the repository:
```bash
git clone https://github.com/VasilGrozdanov/foundry-raffle.git
```

### Key Points:
- **Chainlink VRF** ensures fair randomness in selecting the raffle winner.
- **Chainlink Automation** handles the upkeep (i.e., closing the raffle and picking a winner) without manual intervention.
- Make sure your VRF and Automation subscriptions have enough funds, otherwise picking the winner won't work.


## 🛠️ Usage

### 🔨 Build
Use the [Makefile](https://github.com/VasilGrozdanov/foundry-raffle/blob/main/Makefile) commands **(📝 note: Make sure you have GNU Make installed and add the necessary environment variables in a `.env` file)**, or alternatively foundry commands:
```shell
$ forge build
```

### 🧪 Test

```shell
$ forge test
```

### 🎨 Format

```shell
$ forge fmt
```

### ⛽ Gas Snapshots

```shell
$ forge snapshot
```

### 🔧 Anvil

```shell
$ anvil
```

### 🚀 Deploy

```shell
$ forge script script/DeployRaffle.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```
> ⚠️ **Warning: Using your private key on a chain associated with real money must be avoided!**

 OR
```shell
$ forge script script/DeployRaffle.s.sol --rpc-url <your_rpc_url> --account <your_account> --broadcast
```
> 📝 **Note: Using your --account requires adding wallet first, which is more secure than the plain text private key!**
```Bash
cast wallet import --interactive <name_your_wallet>
```
### 🛠️ Cast

```shell
$ cast <subcommand>
```

### ❓ Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```