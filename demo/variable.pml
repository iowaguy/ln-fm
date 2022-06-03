/* An example state machine to test how to implement functions. */

mtype = {
  AMSG, BMSG, SIG
}

/* Rendezvous communication channels */
chan AtoB = [0] of { mtype };
chan BtoA = [0] of { mtype };

int state[2];
int pids[2];

int testvar[2] = {0, 0};

int testvar2[2] = {0, 0};

bool testvar3[2] = {true, true};

int maxvar = 3;

#define AState      0
#define BState      1
#define CState      2
#define DState      3
#define EState      4
#define FState      5
#define EndState    -1

proctype TestProc(chan snd, rcv; bit i) {
  pids[i] = _pid;
ASTATE:
  state[i] = AState;
  if
    :: rcv ? SIG ->
       if
         :: testvar3[i] == true -> testvar[i] = 2; testvar2[i] = 1; goto BSTATE;
       fi
    :: rcv ? SIG -> testvar[i] = 1; testvar2[i] = 1; goto BSTATE;
    :: snd ! SIG -> testvar[i] = 0; testvar2[i] = 1; goto BSTATE;
    :: snd ! SIG -> testvar[i] = 0; testvar2[i] = 0; goto BSTATE;
  fi

BSTATE:
  state[i] = BState;
  if
    :: testvar3[i] == true && testvar[i] + testvar2[i] == 0 -> goto CSTATE;
    :: testvar3[i] == true && testvar[i] + testvar2[i] == 1 -> goto DSTATE;
    :: testvar3[i] == true && testvar[i] + testvar2[i] == 2 -> goto ESTATE;
    :: testvar3[i] == true && testvar[i] + testvar2[i] >= maxvar -> goto FSTATE;
  fi

CSTATE:
  state[i] = CState;
  goto end;

DSTATE:
  state[i] = DState;
  goto end;

ESTATE:
  state[i] = EState;
  goto end;

FSTATE:
  state[i] = FState;
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
