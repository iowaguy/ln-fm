/* An example state machine to test how to implement functions. */

mtype = {
  AMSG, BMSG, SIG
}

/* Rendezvous communication channels */
chan AtoB = [0] of { mtype };
chan BtoA = [0] of { mtype };

int state[2];
int pids[2];

/* This variable represents the return status of the intermediate
   function calls. */
mtype ret[2];


#define AState      0
#define BState      1
#define CState      2
#define DState      3
#define EndState    -1

/* The HTLC_OPEN state is always eventually followed by either: funded, */
/* ackwait, confirmcomm, fail or close*/
/* ltl phi1 { */
/*   always ( */
/*     (state[0] == HtlcOpenState) */
/*     implies ( */
/*       eventually ( */
/*         ( */
/*           state[0] == FundedState     || */
/*           state[0] == AckWaitState     || */
/*           state[0] == ConfirmCommState || */
/*           state[0] == FailState || */
/*           state[0] == CloseState */
/*         ) */
/*       ) */
/*     ) */
/*   ) */
/* } */

/* ltl state3canBeForever { */
/* 	! ( eventually ( always (state[0] == AckWaitState) ) ) */
/* } */

proctype TestFunc(bit i) {
  do
  :: ret[i] = AMSG; break;
  :: ret[i] = BMSG; break;
  od
}

proctype TestProc(chan snd, rcv; bit i) {
  pids[i] = _pid;
ASTATE:
  state[i] = AState;
  if
  :: rcv ? SIG -> goto BSTATE;
  :: snd ! SIG -> goto BSTATE;
  fi

BSTATE:
  state[i] = BState;
  run TestFunc(i);
  if
  :: ret[i] == AMSG -> goto DSTATE;
  :: ret[i] == BMSG -> goto CSTATE;
  fi

CSTATE:
  state[i] = CState;
  goto end;

DSTATE:
  state[i] = DState;
  goto end;

end:
	state[i] = EndState;
}


init {
  state[0] = AState;
  state[1] = AState;
  run TestProc(AtoB, BtoA, 0);
  run TestProc(BtoA, AtoB, 1);
}
