/* The HTLC_OPEN state is always eventually followed by */
ltl phi1 {
  always (
    (state[0] == HtlcOpenState)
    implies (
      eventually (
        (
          state[0] == AckWaitState ||
          state[0] == CloseState   ||
          state[0] == ConfirmCommState
        )
      )
    )
  )
}
