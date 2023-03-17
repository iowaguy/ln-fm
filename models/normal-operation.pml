/* A state machine of the gossip protocol within the Lightning Network */

mtype = {
  /* These are message types. They can be sent by one node to
     its counterparty across the channel. */
  UPDATE_ADD_HTLC, ERROR, COMMITMENT_SIGNED, REVOKE_AND_ACK,
  UPDATE_FAIL_HTLC, UPDATE_FAIL_MALFORMED_HTLC, UPDATE_FULFILL_HTLC,
}

/* Messages can be delayed in the channel. */
chan AtoB = [1] of { mtype };
chan BtoA = [1] of { mtype };

int state[2];
int pids[2];

/* The number of HTLCs that can be open at a time by a single peer.
   The actual number in the protocol is 483, but we decrease it in our
   model to avoid state-space explosion. */
int MaxCurrentHtlcs = 5;

/* The number of HTLCs opened by the local and remote peers, respectively.
   There needs to be two pools, becuase a node can only remove an HTLC
   added by the counterparty. This is how we track it. */
int localHtlcs[2] = {0, 0};
int remoteHtlcs[2] = {0, 0};

#define FundedState                    0
#define MoreHtlcsWaitState             1
#define FailChannelState               2
#define CommWaitState                  3
#define FulfillWaitState               4
#define CommWait2State                 5
#define RevokeWaitState                6
#define RevokeWait2State               7
#define EndState                       -1

/* From FUNDED a peer will eventually reach ACCEPT or FAIL CHANNEL. */
/* ltl liveness1 { */
/*     always ( */
/*         (state[0] == FundedState) */
/*         implies ( */
/*             eventually( */
/*                     (state[0] == AcceptState || */
/*                      state[0] == FailChannelState) */
/*             ) */
/*         ) */
/*     ) */
/* } */

/* /\* If a peer validates the commitment signed message, the other peer */
/*    should eventually receive a REVOKE_AND_ACK or end in FAIL_CHANNEL. *\/ */
/* ltl liveness2 { */
/*     always ( */
/*       ((state[0] == MoreHtlcsWaitState || state[0] == ValHtlcState) implies */
/*        (eventually */
/*         (((state[0] == ValDesyncComState) implies (next (state[0] == MoreHtlcsWaitState))) || */
/*          ((state[0] == ValPrimaryCommitmentState) implies (next (state[0] == AckWaitState))) || */
/*          ((state[0] == ValConcCommitmentState) implies (next (state[0] == ValConcAckState))) || */
/*          ((state[0] == ValCommitmentState) implies (next (state[0] == HtlcFulfillWaitState)))) */
/*         implies ( */
/*           eventually ( */
/*             (state[0] == ValSeqAck1State || */
/*              state[0] == ValSeqAck2State || */
/*              state[0] == ValConcAckState || */
/*              state[0] == FailChannelState)))))) */
/* } */

inline addLocalHtlc(i) {
  d_step {
    rcv ? UPDATE_ADD_HTLC;
    if
      :: remoteHtlcs[i] + localHtlcs[i] >= MaxCurrentHtlcs -> assert(false)
      :: else -> skip;
    fi
    localHtlcs[i]++;
    printf("Peer %d: Local HTLCs: %d; Remote HTLCs: %d\n", i + 1, localHtlcs[i], remoteHtlcs[i]);
  }
}

inline addRemoteHtlc(i) {
  d_step {
    snd ! UPDATE_ADD_HTLC;
    if
      :: remoteHtlcs[i] + localHtlcs[i] >= MaxCurrentHtlcs -> assert(false)
      :: else -> skip;
    fi
    remoteHtlcs[i]++;
    printf("Peer %d: Local HTLCs: %d; Remote HTLCs: %d\n", i + 1, localHtlcs[i], remoteHtlcs[i]);
  }
}

inline deleteLocalHtlc(i) {
  d_step {
    if
      :: localHtlcs[i] == 0 -> assert(false)
      :: else -> skip;
    fi
    localHtlcs[i]--;
    printf("Peer %d: Local HTLCs: %d\n", i + 1, localHtlcs[i]);
  }
}

inline deleteRemoteHtlc(i) {
  d_step {
    if
      :: remoteHtlcs[i] == 0 -> assert(false)
      :: else -> skip;
    fi
    remoteHtlcs[i]--;
    printf("Peer %d: Remote HTLCs: %d\n", i + 1, remoteHtlcs[i]);
  }
}

proctype LightningNormal(chan snd, rcv; bit i) {
  pids[i] = _pid;

progress_FUNDED:
  state[i] = FundedState;
  if
    // (1)
    :: rcv ? UPDATE_ADD_HTLC -> snd ! UPDATE_FAIL_HTLC; goto end_FAIL_CHANNEL;
    :: rcv ? UPDATE_ADD_HTLC -> snd ! UPDATE_FAIL_MALFORMED_HTLC; goto end_FAIL_CHANNEL;

    // (2)
    :: addLocalHtlc(i) -> goto MORE_HTLCS_WAIT;

    // (3)
    :: addRemoteHtlc(i); goto MORE_HTLCS_WAIT;

    // (4)
    :: addRemoteHtlc(i) -> snd ! COMMITMENT_SIGNED; goto COMM_WAIT;

    // (28)
    :: goto end;

  fi

MORE_HTLCS_WAIT:
  state[i] = MoreHtlcsWaitState;

  if
    :: remoteHtlcs[i] + localHtlcs[i] < MaxCurrentHtlcs - 1 ->
       // Can accept more than one more HTLC
       if
         // (5)
         :: rcv ? COMMITMENT_SIGNED -> snd ! REVOKE_AND_ACK; snd ! COMMITMENT_SIGNED; goto REVOKE_WAIT;

         // (6)
         :: addRemoteHtlc(i) -> snd ! COMMITMENT_SIGNED; goto COMM_WAIT;

         // (7)
         :: addLocalHtlc(i) -> addRemoteHtlc(i); snd ! COMMITMENT_SIGNED; goto COMM_WAIT;

         // (8)
         :: timeout -> snd ! COMMITMENT_SIGNED; goto COMM_WAIT;

         // (9)
         :: rcv ? UPDATE_FAIL_HTLC; goto end_FAIL_CHANNEL;
         :: rcv ? UPDATE_FAIL_MALFORMED_HTLC; goto end_FAIL_CHANNEL;

         // (10)
         :: addRemoteHtlc(i) -> goto MORE_HTLCS_WAIT;

         // (11)
         :: addLocalHtlc(i) -> goto MORE_HTLCS_WAIT;

         // (12)
         :: rcv ? UPDATE_ADD_HTLC -> snd ! UPDATE_FAIL_HTLC; goto end_FAIL_CHANNEL;
         :: rcv ? UPDATE_ADD_HTLC -> snd ! UPDATE_FAIL_MALFORMED_HTLC; goto end_FAIL_CHANNEL;
         :: rcv ? UPDATE_ADD_HTLC -> snd ! ERROR; goto end_FAIL_CHANNEL;

         // (31)
         :: rcv ? COMMITMENT_SIGNED -> goto end_FAIL_CHANNEL;
         :: rcv ? COMMITMENT_SIGNED -> snd ! ERROR; goto end_FAIL_CHANNEL;
       fi
    :: remoteHtlcs[i] + localHtlcs[i] == MaxCurrentHtlcs - 1 ->
       // If local node recieves the last HTLC that puts it at MaxCurrentHtlcs,
       // it must start sending commitments
       if
         // (5)
         :: rcv ? COMMITMENT_SIGNED -> snd ! REVOKE_AND_ACK; snd ! COMMITMENT_SIGNED; goto REVOKE_WAIT;

         // (6)
         :: addRemoteHtlc(i) -> snd ! COMMITMENT_SIGNED -> goto COMM_WAIT;

         // (8)
         :: timeout -> snd ! COMMITMENT_SIGNED; goto COMM_WAIT;

         // (9)
         :: rcv ? UPDATE_FAIL_HTLC; goto end_FAIL_CHANNEL;
         :: rcv ? UPDATE_FAIL_MALFORMED_HTLC; goto end_FAIL_CHANNEL;

         // (12)
         :: rcv ? UPDATE_ADD_HTLC -> snd ! UPDATE_FAIL_HTLC; goto end_FAIL_CHANNEL;
         :: rcv ? UPDATE_ADD_HTLC -> snd ! UPDATE_FAIL_MALFORMED_HTLC; goto end_FAIL_CHANNEL;
         :: rcv ? UPDATE_ADD_HTLC -> snd ! ERROR; goto end_FAIL_CHANNEL;

         // (31)
         :: rcv ? COMMITMENT_SIGNED -> goto end_FAIL_CHANNEL;
         :: rcv ? COMMITMENT_SIGNED -> snd ! ERROR; goto end_FAIL_CHANNEL;
       fi
  fi

REVOKE_WAIT:
  state[i] = RevokeWaitState;
  if
    :: remoteHtlcs[i] == 1 && localHtlcs[i] == 0 ->
       if
         // (13)
         :: rcv ? REVOKE_AND_ACK -> snd ! UPDATE_FULFILL_HTLC; snd ! COMMITMENT_SIGNED; goto COMM_WAIT_2;

         // (15)
         :: timeout -> snd ! ERROR; goto end_FAIL_CHANNEL;
         :: timeout -> goto end_FAIL_CHANNEL;
         :: rcv ? ERROR -> goto end_FAIL_CHANNEL;
       fi
    :: else ->
       if
         // (14)
         :: rcv ? REVOKE_AND_ACK -> goto FULFILL_WAIT;

         // (15)
         :: timeout -> snd ! ERROR; goto end_FAIL_CHANNEL;
         :: timeout -> goto end_FAIL_CHANNEL;
         :: rcv ? ERROR -> goto end_FAIL_CHANNEL;
       fi
  fi
COMM_WAIT:
  state[i] = CommWaitState;
  if
    // (16)
    :: rcv ? REVOKE_AND_ACK -> goto COMM_WAIT;

    // (17)
    :: rcv ? COMMITMENT_SIGNED -> snd ! REVOKE_AND_ACK; goto COMM_WAIT;

    // (18)
    :: rcv ? REVOKE_AND_ACK -> goto FULFILL_WAIT;

    // (19)
    :: rcv ? COMMITMENT_SIGNED -> snd ! REVOKE_AND_ACK; goto FULFILL_WAIT;

    // (20)
    :: timeout -> snd ! ERROR; goto end_FAIL_CHANNEL;
    :: timeout -> goto end_FAIL_CHANNEL;
    :: rcv ? ERROR -> goto end_FAIL_CHANNEL;
    :: rcv ? REVOKE_AND_ACK -> goto end_FAIL_CHANNEL;
    :: rcv ? REVOKE_AND_ACK -> snd ! ERROR; goto end_FAIL_CHANNEL;
  fi

FULFILL_WAIT:
  state[i] = FulfillWaitState;
  if
    :: localHtlcs[i] == 0 && remoteHtlcs[i] == 1 ->
       if
         // (24)
         :: rcv ? UPDATE_FULFILL_HTLC -> snd ! COMMITMENT_SIGNED; deleteRemoteHtlc(i); goto COMM_WAIT_2;

         // (23)
         :: timeout -> snd ! ERROR; goto end_FAIL_CHANNEL;
         :: timeout -> goto end_FAIL_CHANNEL;
         :: rcv ? ERROR -> goto end_FAIL_CHANNEL;
         :: rcv ? UPDATE_FULFILL_HTLC -> goto end_FAIL_CHANNEL;
         :: rcv ? UPDATE_FULFILL_HTLC -> snd ! ERROR; goto end_FAIL_CHANNEL;
       fi
    :: localHtlcs[i] == 1 && remoteHtlcs[i] == 0 ->
       if
         // (25)
         :: snd ! UPDATE_FULFILL_HTLC -> snd ! COMMITMENT_SIGNED; deleteLocalHtlc(i); goto COMM_WAIT_2;

         // (23)
         :: timeout -> snd ! ERROR; goto end_FAIL_CHANNEL;
         :: timeout -> goto end_FAIL_CHANNEL;
         :: rcv ? ERROR -> goto end_FAIL_CHANNEL;
       fi
    :: localHtlcs[i] > 1 ->
       if
         // (22)
         :: snd ! UPDATE_FULFILL_HTLC -> deleteLocalHtlc(i); goto FULFILL_WAIT;

         // (23)
         :: timeout -> snd ! ERROR; goto end_FAIL_CHANNEL;
         :: timeout -> goto end_FAIL_CHANNEL;
         :: rcv ? ERROR -> goto end_FAIL_CHANNEL;
         :: rcv ? UPDATE_FULFILL_HTLC -> goto end_FAIL_CHANNEL;
         :: rcv ? UPDATE_FULFILL_HTLC -> snd ! ERROR; goto end_FAIL_CHANNEL;
       fi

    :: remoteHtlcs[i] > 1 ->
       if
         // (21)
         :: rcv ? UPDATE_FULFILL_HTLC -> deleteRemoteHtlc(i); goto FULFILL_WAIT;

         // (23)
         :: timeout -> snd ! ERROR; goto end_FAIL_CHANNEL;
         :: timeout -> goto end_FAIL_CHANNEL;
         :: rcv ? ERROR -> goto end_FAIL_CHANNEL;
         :: rcv ? UPDATE_FULFILL_HTLC -> goto end_FAIL_CHANNEL;
         :: rcv ? UPDATE_FULFILL_HTLC -> snd ! ERROR; goto end_FAIL_CHANNEL;
       fi

    :: else ->
       if
         // (21)
         :: rcv ? UPDATE_FULFILL_HTLC -> deleteRemoteHtlc(i); goto FULFILL_WAIT;

         // (22)
         :: snd ! UPDATE_FULFILL_HTLC -> deleteLocalHtlc(i); goto FULFILL_WAIT;

         // (23)
         :: timeout -> snd ! ERROR; goto end_FAIL_CHANNEL;
         :: timeout -> goto end_FAIL_CHANNEL;
         :: rcv ? ERROR -> goto end_FAIL_CHANNEL;
         :: rcv ? UPDATE_FULFILL_HTLC -> goto end_FAIL_CHANNEL;
         :: rcv ? UPDATE_FULFILL_HTLC -> snd ! ERROR; goto end_FAIL_CHANNEL;
       fi
  fi

COMM_WAIT_2:
  state[i] = CommWait2State;
  if
    // (26)
    :: rcv ? COMMITMENT_SIGNED -> snd ! REVOKE_AND_ACK; goto REVOKE_WAIT_2;

    // (27)
    :: timeout -> snd ! ERROR; goto end_FAIL_CHANNEL;
    :: timeout -> goto end_FAIL_CHANNEL;
    :: rcv ? ERROR -> goto end_FAIL_CHANNEL;
    :: rcv ? COMMITMENT_SIGNED -> goto end_FAIL_CHANNEL;
    :: rcv ? COMMITMENT_SIGNED -> snd ! ERROR; goto end_FAIL_CHANNEL;
  fi

REVOKE_WAIT_2:
  state[i] = RevokeWait2State;
  if
    // (29)
    :: rcv ? REVOKE_AND_ACK -> goto progress_FUNDED;

    // (30)
    :: timeout -> snd ! ERROR; goto end_FAIL_CHANNEL;
    :: timeout -> goto end_FAIL_CHANNEL;
    :: rcv ? ERROR -> goto end_FAIL_CHANNEL;
    :: rcv ? REVOKE_AND_ACK -> goto end_FAIL_CHANNEL;
    :: rcv ? REVOKE_AND_ACK -> snd ! ERROR; goto end_FAIL_CHANNEL;
  fi

end_FAIL_CHANNEL:
  state[i] = FailChannelState;
  goto end;

end:
  state[i] = EndState;
}


init {
  atomic {
    state[0] = FundedState;
    state[1] = FundedState;
    run LightningNormal(AtoB, BtoA, 0);
    run LightningNormal(BtoA, AtoB, 1);
  }
}
