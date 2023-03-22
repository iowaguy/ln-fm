trace {
  do
    :: state[0] != FailChannelState && state[1] != FailChannelState ->
       if
         :: AtoB ? COMMITMENT_SIGNED //; BtoA ! REVOKE_AND_ACK
         :: AtoB ? UPDATE_ADD_HTLC
         :: AtoB ? REVOKE_AND_ACK
         :: AtoB ? ERROR
         :: AtoB ? UPDATE_FAIL_HTLC
         :: AtoB ? UPDATE_FAIL_MALFORMED_HTLC
         :: AtoB ? UPDATE_FULFILL_HTLC
         :: AtoB ! _
         :: BtoA ? _
         :: BtoA ! _
       fi
    :: else
  od
}
