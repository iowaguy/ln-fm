// A payment should either eventually end up back in Funded, or fail.

#define p (state[0] == FundedState || state[0] == FailChannelState)

ltl Liveness {
  always eventually p
}
