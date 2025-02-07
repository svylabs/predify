#!/usr/bin/env node
import { PRNG, Actor, Action, Runner, Agent, Environment } from "@svylabs/flocc-ext";
import type { Account, Web3RunnerOptions, SnapshotProvider, RunContext } from "@svylabs/flocc-ext";
import {ethers} from 'hardhat';
//const { ethers } = pkg;
import { deployContracts } from "./deploy";
import { ContractSnapshotProvider } from "./snapshot";
import { BorrowAction } from "./actions";

 // Define Actors here
 const numActors = 10;

async function main() {
    
    const contracts = await deployContracts();
    const addrs = await ethers.getSigners();

    const env = new Environment();

    const actors: Actor[] = [];
    for (let i = 0; i < numActors; i++) {
        const account: Account = {
           address: addrs[i].address,
           type: "key",
           value: addrs[i]
        }
        // Pass only the required contract instead of passing all contracts
        const borrowAction = new BorrowAction(contracts);
        const actor = new Actor(
            "Borrower",
            account,
            [],
            [{ action: borrowAction, probability: 0.8 }] // 80% probability
        );
        actors.push(actor);
        env.addAgent(actor);
   }

    // Configure a Runner

    // Initialize and run simulation
    const options = {
        iterations: 10,
        randomSeed: "test-seed",
        shuffleAgents: false
    };

    const snapshotProvider = new ContractSnapshotProvider(contracts);

    const runner = new Runner(actors, snapshotProvider, options);
    await runner.run();
}

console.log(process.argv);
main()
.then(() => {
    console.log("Simulation completed successfully");
    process.exit(0)
})
.catch(error => {
    console.error(error);
    process.exit(1);
});
    
    
    