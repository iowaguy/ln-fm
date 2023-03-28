#define p (localHtlcs[0] + remoteHtlcs[0] < MaxCurrentHtlcs)
#define q (localHtlcs[1] + remoteHtlcs[1] < MaxCurrentHtlcs)

ltl NoGriefing {
  always (p && q)
}
