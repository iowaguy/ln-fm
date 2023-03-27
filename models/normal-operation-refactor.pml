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

/* A boolean that indicates if all the HTLCs have been fulfilled or
   not. All HTLCs must be fulfilled before new ones can be added
   (i.e. before the state machine can return to `FUNDED`). */
bool fulfilled[2] = { false, false };

/* A boolean that indicates whether the two peers have gotten their
   commitments out of sync. */
bool desynced[2] = { false, false };

/* The number of HTLCs that can be open at a time by a single peer.
   The actual number in the protocol is 483, but we decrease it in our
   model to avoid state-space explosion. */
int maxCurrentHtlcs = 2;

/* The number of HTLCs opened by the local and remote peers, respectively.
   There needs to be two pools, becuase a node can only remove an HTLC
   added by it's counterparty. This is how we track it. */
int localHtlcs[2] = {0, 0};
int remoteHtlcs[2] = {0, 0};

/* This variable indicates whether a peer has more HTLCs it needs
   to delete before it can be considered settled. */
bool is_more[2] = { false, false };

#define FundedState                    0
#define MoreHtlcsWaitState             2
#define FailChannelState               3
#define CloseChannelState              4
#define OpenChannelState               5
#define CommitmentAckWaitState         6
#define AckWaitState                   12
#define HtlcFulfillWaitState           15
#define ResyncState                    16
#define AcceptState                    19
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

/* If a peer validates the commitment signed message, the other peer
   should eventually receive a REVOKE_AND_ACK or end in FAIL_CHANNEL. */
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

proctype LightningNormal(chan snd, rcv; bit i) {
  pids[i] = _pid;

FUNDED:
  state[i] = FundedState;
  if
    // (1)
    :: snd ! UPDATE_ADD_HTLC -> goto MORE_HTLCS_WAIT;
    :: rcv ? UPDATE_ADD_HTLC -> goto MORE_HTLCS_WAIT;

    // (2)
    :: rcv ? ERROR -> goto FAIL_CHANNEL;
    :: snd ! ERROR -> goto FAIL_CHANNEL;

    // (3)
    :: rcv ? UPDATE_ADD_HTLC ->
       if
         :: snd ! UPDATE_FAIL_HTLC -> goto FAIL_CHANNEL;
         :: snd ! UPDATE_FAIL_MALFORMED_HTLC -> goto FAIL_CHANNEL;
         :: snd ! ERROR -> goto FAIL_CHANNEL;
         :: timeout -> goto FAIL_CHANNEL;
       fi
  fi

MORE_HTLCS_WAIT:
  state[i] = MoreHtlcsWaitState;
  if
    // (4)
    :: rcv ? UPDATE_ADD_HTLC -> goto MORE_HTLCS_WAIT;
    :: snd ! UPDATE_ADD_HTLC -> goto MORE_HTLCS_WAIT;

    // (5)
    :: rcv ? COMMITMENT_SIGNED ->
       if
         :: snd ! REVOKE_AND_ACK -> goto ACK_WAIT;
         :: snd ! COMMITMENT_SIGNED -> goto ACK_WAIT;
       fi

    // (6)
    :: rcv ? COMMITMENT_SIGNED ->
       if
         :: snd

       fi
  fi

RESYNC:
  state[i] = ResyncState;
  do
    /* A `COMMITMENT_SIGNED` signed was sent concurrently (in addition to concurrent HTLCs),
       the local node needs to ack it. (43) */
    :: rcv ? COMMITMENT_SIGNED ->
       if
         :: snd ! REVOKE_AND_ACK -> goto VAL_DESYNC_COM;
         :: snd ! ERROR; goto FAIL_CHANNEL;
         :: timeout -> goto FAIL_CHANNEL;
       fi

    /* Fail the channel if the other node timesout or sends an error during
       resynchronization. (45) */
    :: snd ! ERROR; goto FAIL_CHANNEL;
    :: rcv ? ERROR -> goto FAIL_CHANNEL;

    /* The nodes exchanged `UPDATE_ADD_HTLC`s concurrently. One node also send a
       `COMMITMENT_SIGNED`, which the counterparty has acked but not sent their own
       `COMMITMENT_SIGNED` (yet). (44) */
    :: rcv ? REVOKE_AND_ACK -> goto VAL_SEQ_ACK_1;

    :: timeout -> goto FAIL_CHANNEL;
  od

COMM_ACK_WAIT:
  state[i] = CommitmentAckWaitState;
  if
    /* An `UPDATE_ADD_HTLC` was received after the local node already sent a
       commitment. Nodes are out of sync and need to be resynchronized. (41) */
    :: rcv ? UPDATE_ADD_HTLC -> desynced[i] = true; goto VAL_HTLC;

    /* There is no timeout specified in the specification, but there should be. */
    /* If the local node times out, send an `ERROR`. (17) */
    :: snd ! ERROR -> goto FAIL_CHANNEL;
    :: timeout -> goto FAIL_CHANNEL;

    /* If an `ERROR` is received, fail the channel. (17) */
    :: rcv ? ERROR -> goto FAIL_CHANNEL;

    /* Commitments were sent sequentially. The counterparty acked a commitment before
       sending its own. (12) */
    :: rcv ? REVOKE_AND_ACK; goto VAL_SEQ_ACK_1;

    /* This transition means that the counterparty sent a commitment before
       receiving the local commitment, i.e., they are concurrent. This is fine as long as
       neither party both commits and revokes before receiving the counterparty's
       commitment. (19) */
    :: rcv ? COMMITMENT_SIGNED; goto VAL_CONC_COMM;
  fi

ACK_WAIT:
  state[i] = AckWaitState;
  if
    /* Receive the final ack. (26) */
    :: rcv ? REVOKE_AND_ACK -> goto VAL_SEQ_ACK_2;

    /* If an `ERROR` is received, fail the channel. There is no timeout specified
       in the specification, but there should be. If the local node times out, send
       an `ERROR`. (25) */
    :: snd ! ERROR -> goto FAIL_CHANNEL;
    :: rcv ? ERROR -> goto FAIL_CHANNEL;

    :: timeout -> goto FAIL_CHANNEL;
  fi

HTLC_FULFILL_WAIT:
  state[i] = HtlcFulfillWaitState;
  do
    /* HTLC deletion was successful, and no more HTLCs need to be settled. Complete run. (36) */
    :: fulfilled[i] == true -> goto ACCEPT;

    /* Send an HTLC fulfillment, if there are more HTLCs and this round of HTLCs has not been fulfilled. (37) */
    :: fulfilled[i] == false && is_more[i] == true ->
       if
         // TODO here I should only be able to send an UPDATE_FULFILL_HTLC if there are remaining outstanding HTLCs.
         // If there are no remaining outstanding HTLCs, then this should cause an error path to be followed.
         :: snd ! UPDATE_FULFILL_HTLC -> sent_or_received[i] = SEND; goto DEL_HTLC;
         :: snd ! UPDATE_FAIL_HTLC -> sent_or_received[i] = SEND; goto DEL_HTLC;
         :: snd ! ERROR -> goto FAIL_CHANNEL;
         :: timeout -> goto FAIL_CHANNEL;
       fi


    /* Received an HTLC fulfillment, when this round of HTLCs had not yet been fulfilled, and there are still
       pending HTLCs. Proceed to validation steps. (33) */
    :: fulfilled[i] == false && is_more[i] == true ->
       if
         :: rcv ? UPDATE_FULFILL_HTLC -> goto VAL_FULFILL;
         :: rcv ? UPDATE_FAIL_HTLC -> goto VAL_FULFILL;
         :: snd ! ERROR -> goto FAIL_CHANNEL;
         :: timeout -> goto FAIL_CHANNEL;
       fi

    /* All HTLCs have been fulfilled for this round and none are left to process, but
       the two parties still need to exchange commitments and revocations. This is to
       reduce the complexity (i.e. size) of the logic that needs to be in the
       redeemable transactions. (50) */
    :: fulfilled[i] == false && is_more[i] == false -> fulfilled[i] = true; goto MORE_HTLCS_WAIT;

    /* The local node might time out and thus be forced to fail the channel,
       however, the transaction is actually complete. The remaining commitment/ack
       pair is just to make the transactions smaller, for block space
       efficiency. (30) */
    :: fulfilled[i] == false ->
       if
         :: snd ! ERROR -> goto FAIL_CHANNEL;
         :: rcv ? ERROR -> goto FAIL_CHANNEL;
         :: timeout -> goto FAIL_CHANNEL;
       fi
  od

FAIL_CHANNEL:
  state[i] = FailChannelState;
  goto end;

ACCEPT:
  state[i] = AcceptState;
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
