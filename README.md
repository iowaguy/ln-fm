# Payout Race README
Also note that a full implementation of `lnd` is included.

## Running Model Checker
Run `./lnverifier` to test the model with SPIN. It should report all states as reached, and not report any deadlocks or livelocks.

Providing a numeric argument will verify the corresponding property in the paper, e.g., `./lnverifier 1` will verify property 1. Properties are numbered 1-5. If a property does not verify, an error will be thrown.

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
