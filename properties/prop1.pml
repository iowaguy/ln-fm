notrace {
start:
  do
    :: AtoB ! REVOKE_AND_ACK -> goto send_atob_ack;
    :: AtoB ! UPDATE_ADD_HTLC
    :: AtoB ! COMMITMENT_SIGNED
    :: AtoB ! UPDATE_FULFILL_HTLC
    :: AtoB ! ERROR
    :: AtoB ! UPDATE_FAIL_HTLC
    :: AtoB ! UPDATE_FAIL_MALFORMED_HTLC
    :: AtoB ? COMMITMENT_SIGNED
    :: AtoB ? UPDATE_ADD_HTLC
    :: AtoB ? UPDATE_FULFILL_HTLC
    :: AtoB ? REVOKE_AND_ACK
    :: AtoB ? ERROR
    :: AtoB ? UPDATE_FAIL_HTLC
    :: AtoB ? UPDATE_FAIL_MALFORMED_HTLC
    :: BtoA ! REVOKE_AND_ACK -> goto send_btoa_ack;
    :: BtoA ! UPDATE_ADD_HTLC
    :: BtoA ! COMMITMENT_SIGNED
    :: BtoA ! UPDATE_FULFILL_HTLC
    :: BtoA ! ERROR
    :: BtoA ! UPDATE_FAIL_HTLC
    :: BtoA ! UPDATE_FAIL_MALFORMED_HTLC
    :: BtoA ? COMMITMENT_SIGNED
    :: BtoA ? UPDATE_ADD_HTLC
    :: BtoA ? UPDATE_FULFILL_HTLC
    :: BtoA ? REVOKE_AND_ACK
    :: BtoA ? ERROR
    :: BtoA ? UPDATE_FAIL_HTLC
    :: BtoA ? UPDATE_FAIL_MALFORMED_HTLC
  od
send_atob_ack:
  do
    :: BtoA ? COMMITMENT_SIGNED -> goto start;
  od
send_btoa_ack:
  do
    :: AtoB ? COMMITMENT_SIGNED -> goto start;
  od
}
