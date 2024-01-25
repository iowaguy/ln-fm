trace {
start:
  do
    :: AtoB ? COMMITMENT_SIGNED -> goto recv_atob_comm;
    :: AtoB ? UPDATE_ADD_HTLC
    :: AtoB ? UPDATE_FULFILL_HTLC
    :: AtoB ? REVOKE_AND_ACK
    :: AtoB ? ERROR
    :: AtoB ? UPDATE_FAIL_HTLC
    :: AtoB ? UPDATE_FAIL_MALFORMED_HTLC
    :: AtoB ! UPDATE_ADD_HTLC
    :: AtoB ! COMMITMENT_SIGNED
    :: AtoB ! UPDATE_FULFILL_HTLC
    :: AtoB ! REVOKE_AND_ACK
    :: AtoB ! ERROR
    :: AtoB ! UPDATE_FAIL_HTLC
    :: AtoB ! UPDATE_FAIL_MALFORMED_HTLC
    :: BtoA ? COMMITMENT_SIGNED -> goto recv_btoa_comm;
    :: BtoA ? UPDATE_ADD_HTLC
    :: BtoA ? UPDATE_FULFILL_HTLC
    :: BtoA ? REVOKE_AND_ACK
    :: BtoA ? ERROR
    :: BtoA ? UPDATE_FAIL_HTLC
    :: BtoA ? UPDATE_FAIL_MALFORMED_HTLC
    :: BtoA ! UPDATE_ADD_HTLC
    :: BtoA ! COMMITMENT_SIGNED
    :: BtoA ! UPDATE_FULFILL_HTLC
    :: BtoA ! REVOKE_AND_ACK
    :: BtoA ! ERROR
    :: BtoA ! UPDATE_FAIL_HTLC
    :: BtoA ! UPDATE_FAIL_MALFORMED_HTLC
  od
recv_atob_comm:
  do
    :: BtoA ! REVOKE_AND_ACK -> goto start;
    :: BtoA ? _ -> goto recv_atob_comm;
    :: AtoB ! _ -> goto recv_atob_comm;
    :: AtoB ? _ -> goto recv_atob_comm;
  od
recv_btoa_comm:
  do
    :: AtoB ! REVOKE_AND_ACK -> goto start;
    :: AtoB ? _ -> goto recv_btoa_comm;
    :: BtoA ! _ -> goto recv_btoa_comm;
    :: BtoA ? _ -> goto recv_btoa_comm;
  od
}
