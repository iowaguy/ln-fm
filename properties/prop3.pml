// If a peer is in FUNDED, it must have no open HTLCs
ltl BalanceInconsistency {
  (state[0] == FundedState) implies (localHtlcs[0] == 0 && remoteHtlcs[0] == 0)
}
