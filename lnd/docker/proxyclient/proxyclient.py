#!/usr/bin/env python3
import bitcoinlib.transactions as t
import bitcoinlib.services.bitcoind as btcd
import bitcoinlib.services.services
import sys

def getrawtx(path: str) -> bytes:
    with open(path, 'rb') as f:
        return f.read()

def parse_tx_from_raw(path: str) -> t.Transaction:
    with open(path, 'rb') as f:
        tx_raw = f.read()
        return t.Transaction.parse(tx_raw)

if __name__ == "__main__":
    tx = parse_tx_from_raw(sys.argv[1])
    # bc = btcd.BitcoindClient(network='simnet', base_url='https://devuser:devpass@btcd:18555')
    # bc.sendrawtransaction(getrawtx(sys.argv[1]))

    serv = services.Service(network='simnet', strict=False)
    serv.sendrawtransaction(getrawtx(sys.argv[1]))
