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
