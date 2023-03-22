// A payment should either eventually end up back in Funded, or fail.
ltl liveness {
  eventually (always (state[0] == FundedState ||
                      state[0] == FailChannelState
  ))
}
