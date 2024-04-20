# Payout Race README
## Docker
Our model can be checked with the provided Docker setup. First, build the docker image. From inside the directory, run

    docker build -t payoutrace .
    
Then run the container with

    docker run payoutrace <N>

where `<N>` is an integer 1-5 representing a property to verify. These correspond to the properties in the paper and are numbered as such. The argument `<N>` can also be left out to check the model for deadlocks and livelocks. If a property does not verify, an error will be thrown. Errors from Spin can be difficult to parse, look for the following messages near the top of the console output.

    pan:1: event_trace error 

or

    pan:1: assertion violated

If successful, the output will report all states as reached, and not report any deadlocks or livelocks. There should be errors for properties 3 and 4, but not for any others.

# Non-Docker instructions
Note that a full implementation of `lnd` is included.

## Running Model Checker
The SPIN model checker must be installed and available from the command line. Run `./lnverifier` to test the model with SPIN. It should report all states as reached, and not report any deadlocks or livelocks.

Providing a numeric argument will verify the corresponding property in the paper, e.g., `./lnverifier -p 1` will verify property 1. Properties are numbered 1-5. If a property does not verify, an error will be thrown.

    pan:1: event_trace error (no matching event) (at depth 68)
    pan: wrote model.tmp.pml.trail

or

    pan:1: assertion violated

## Running Attack Reproduction PoC
Run the following to setup the `lnd` and `btcd` nodes, create a LN channel and prepare the nodes to make payments.
```shell
./reproctl setup
```

To execute the attack, run
```
./reproctl attack 1
```

If I want to step through each phase in the attack, comment out blocks in the `attack()` function to stop at the desired phase before running.

To view time-until-maturity, run
```shell
docker exec -it bob lncli --network=simnet pendingchannels
```

To view mempool
```shell
./reproctl btcctl getmempoolinfo
./reproctl btcctl getmempoolentry <txid>
```
