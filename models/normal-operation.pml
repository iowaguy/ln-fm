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
int MaxCurrentHtlcs = 10;

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

FUNDED:
end_FUNDED:
progress_FUNDED:
accept_FUNDED:
  state[i] = FundedState;

  // This assertion is Property 3
  assert(localHtlcs[i] == 0 && remoteHtlcs[i] == 0)
  if
    // (1)
    :: rcv ? UPDATE_ADD_HTLC -> snd ! UPDATE_FAIL_HTLC; goto FAIL_CHANNEL;
    :: rcv ? UPDATE_ADD_HTLC -> snd ! UPDATE_FAIL_MALFORMED_HTLC; goto FAIL_CHANNEL;

    // (2)
    :: addLocalHtlc(i) -> state[i] = MoreHtlcsWaitState; goto MORE_HTLCS_WAIT;

    // (3)
    :: addRemoteHtlc(i) -> state[i] = MoreHtlcsWaitState; goto MORE_HTLCS_WAIT;
  fi

MORE_HTLCS_WAIT:
  state[i] = MoreHtlcsWaitState;
  if
    :: remoteHtlcs[i] + localHtlcs[i] < MaxCurrentHtlcs ->
       // Can accept more than one more HTLC
       if
         // (5)
         :: rcv ? COMMITMENT_SIGNED -> snd ! REVOKE_AND_ACK; snd ! COMMITMENT_SIGNED; goto REVOKE_WAIT;

         // (8)
         :: snd ! COMMITMENT_SIGNED; goto COMM_WAIT;

         // (9)
         :: rcv ? UPDATE_FAIL_HTLC; goto FAIL_CHANNEL;
         :: rcv ? UPDATE_FAIL_MALFORMED_HTLC; goto FAIL_CHANNEL;

         // (10)
         :: addRemoteHtlc(i) -> goto MORE_HTLCS_WAIT;

         // (11)
         :: addLocalHtlc(i) -> goto MORE_HTLCS_WAIT;

         // (12)
         :: rcv ? UPDATE_ADD_HTLC -> snd ! UPDATE_FAIL_HTLC; goto FAIL_CHANNEL;
         :: rcv ? UPDATE_ADD_HTLC -> snd ! UPDATE_FAIL_MALFORMED_HTLC; goto FAIL_CHANNEL;
         :: rcv ? UPDATE_ADD_HTLC -> snd ! ERROR; goto FAIL_CHANNEL;

         // (31)
         :: rcv ? COMMITMENT_SIGNED -> goto FAIL_CHANNEL;
         :: rcv ? COMMITMENT_SIGNED -> snd ! ERROR; goto FAIL_CHANNEL;
       fi
    :: remoteHtlcs[i] + localHtlcs[i] == MaxCurrentHtlcs ->
       // If local node recieves the last HTLC that puts it at MaxCurrentHtlcs,
       // it must start sending commitments
       if
         // (5)
         :: rcv ? COMMITMENT_SIGNED -> snd ! REVOKE_AND_ACK; snd ! COMMITMENT_SIGNED; goto REVOKE_WAIT;

         // (8)
         :: snd ! COMMITMENT_SIGNED; goto COMM_WAIT;

         // (9)
         :: rcv ? UPDATE_FAIL_HTLC; goto FAIL_CHANNEL;
         :: rcv ? UPDATE_FAIL_MALFORMED_HTLC; goto FAIL_CHANNEL;

         // (12)
         :: rcv ? UPDATE_ADD_HTLC -> snd ! UPDATE_FAIL_HTLC; goto FAIL_CHANNEL;
         :: rcv ? UPDATE_ADD_HTLC -> snd ! UPDATE_FAIL_MALFORMED_HTLC; goto FAIL_CHANNEL;
         :: rcv ? UPDATE_ADD_HTLC -> snd ! ERROR; goto FAIL_CHANNEL;

         // (31)
         :: rcv ? COMMITMENT_SIGNED -> goto FAIL_CHANNEL;
         :: rcv ? COMMITMENT_SIGNED -> snd ! ERROR; goto FAIL_CHANNEL;
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
         :: snd ! ERROR; goto FAIL_CHANNEL;
         :: goto FAIL_CHANNEL;
         :: rcv ? ERROR -> goto FAIL_CHANNEL;
       fi
    :: else ->
       if
         // (14)
         :: rcv ? REVOKE_AND_ACK -> goto FULFILL_WAIT;

         // (15)
         :: snd ! ERROR; goto FAIL_CHANNEL;
         :: goto FAIL_CHANNEL;
         :: rcv ? ERROR -> goto FAIL_CHANNEL;
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
    :: snd ! ERROR; goto FAIL_CHANNEL;
    :: goto FAIL_CHANNEL;
    :: rcv ? ERROR -> goto FAIL_CHANNEL;
    :: rcv ? REVOKE_AND_ACK -> goto FAIL_CHANNEL;
    :: rcv ? REVOKE_AND_ACK -> snd ! ERROR; goto FAIL_CHANNEL;
  fi

FULFILL_WAIT:
  state[i] = FulfillWaitState;
  if
    :: localHtlcs[i] == 0 && remoteHtlcs[i] == 0 ->
       if
         // (x)
         :: rcv ? COMMITMENT_SIGNED -> snd ! REVOKE_AND_ACK; snd ! COMMITMENT_SIGNED; goto REVOKE_WAIT_2;

         // (25)
         :: snd ! COMMITMENT_SIGNED -> goto COMM_WAIT_2;

         // (23)
         :: snd ! ERROR; goto FAIL_CHANNEL;
         :: goto FAIL_CHANNEL;
         :: rcv ? ERROR -> goto FAIL_CHANNEL;
       fi
    :: localHtlcs[i] > 0 ->
       if
         // (22)
         :: snd ! UPDATE_FULFILL_HTLC -> deleteLocalHtlc(i); goto FULFILL_WAIT;

         // (23)
         :: snd ! ERROR; goto FAIL_CHANNEL;
         :: goto FAIL_CHANNEL;
         :: rcv ? ERROR -> goto FAIL_CHANNEL;
         :: rcv ? UPDATE_FULFILL_HTLC -> goto FAIL_CHANNEL;
         :: rcv ? UPDATE_FULFILL_HTLC -> snd ! ERROR; goto FAIL_CHANNEL;
       fi

    :: remoteHtlcs[i] > 0 ->
       if
         // (21)
         :: rcv ? UPDATE_FULFILL_HTLC -> deleteRemoteHtlc(i); goto FULFILL_WAIT;

         // (23)
         :: snd ! ERROR; goto FAIL_CHANNEL;
         :: goto FAIL_CHANNEL;
         :: rcv ? ERROR -> goto FAIL_CHANNEL;
         :: rcv ? UPDATE_FULFILL_HTLC -> goto FAIL_CHANNEL;
         :: rcv ? UPDATE_FULFILL_HTLC -> snd ! ERROR; goto FAIL_CHANNEL;
       fi
  fi

COMM_WAIT_2:
  state[i] = CommWait2State;
  if
    // (26)
    :: rcv ? COMMITMENT_SIGNED -> snd ! REVOKE_AND_ACK; goto REVOKE_WAIT_2;

    // (27)
    :: snd ! ERROR; goto FAIL_CHANNEL;
    :: goto FAIL_CHANNEL;
    :: rcv ? ERROR -> goto FAIL_CHANNEL;
    :: rcv ? COMMITMENT_SIGNED -> goto FAIL_CHANNEL;
    :: rcv ? COMMITMENT_SIGNED -> snd ! ERROR; goto FAIL_CHANNEL;
  fi

REVOKE_WAIT_2:
  state[i] = RevokeWait2State;
  if
    // (29)
    :: rcv ? REVOKE_AND_ACK -> goto FUNDED;

    // (30)
    :: snd ! ERROR; goto FAIL_CHANNEL;
    :: goto FAIL_CHANNEL;
    :: rcv ? ERROR -> goto FAIL_CHANNEL;
    :: rcv ? REVOKE_AND_ACK -> goto FAIL_CHANNEL;
    :: rcv ? REVOKE_AND_ACK -> snd ! ERROR; goto FAIL_CHANNEL;
  fi

FAIL_CHANNEL:
end_FAIL_CHANNEL:
  state[i] = FailChannelState;
  // Clear the receive channel, so that the other peer can make progress
  if
    :: rcv ? _ -> goto FAIL_CHANNEL;
    :: timeout -> skip
  fi
}


init {
  atomic {
    state[0] = FundedState;
    state[1] = FundedState;
    run LightningNormal(AtoB, BtoA, 0);
    run LightningNormal(BtoA, AtoB, 1);
  }
}
