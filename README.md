# Escrow Smart Contract Project

This repository contains a smart contract for an Escrow system. The contract facilitates secure transactions between buyers and sellers with the inclusion of an arbitrator to resolve any disputes. The project includes comprehensive scripts for deployment and configuration, as well as unit and integration tests.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html)
- [Node.js](https://nodejs.org/en/download/) (optional, for managing JavaScript dependencies)
- [npm](https://www.npmjs.com/get-npm) or [yarn](https://classic.yarnpkg.com/en/docs/install/) (optional, for managing JavaScript dependencies)

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/rahulthakkar796/escrow-contracts.git
cd escrow-contracts
```

### 2. Install Foundry
Follow the instructions in the Foundry Book to install Foundry.

### Compilation
Compile the smart contracts using Foundry:

```bash
forge build
```

### Running Tests
#### Run the tests to ensure the contracts work as expected.

### Unit Tests

```bash
forge test
```

### Integration Tests
#### Integration tests are included with the unit tests. They validate that the deployment and configuration scripts work correctly and that the contracts interact as expected.

### Coverage Report
#### Generate a coverage report:

```bash
forge coverage --report lcov
genhtml -o report --branch-coverage lcov.info 
```

#### Open the index.html file in the report directory in your web browser to view the coverage report.

### Project Structure
* src/: Main smart contracts.
* script/: Deployment and configuration scripts.
* test/: Unit and integration tests.