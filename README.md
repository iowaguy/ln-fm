# State Machine

``` mermaid
stateDiagram-v2
    direction LR

    classDef red fill:#f00,color:white,font-weight:bold
    classDef blue fill:#00ff,color:white,font-weight:bold

    class FAIL_CHANNEL red
    class FUNDED blue

    %% Pseudo transitions
    [*] --> FUNDED: (0)\n! FUNDING_LOCKED\n-----------------------------\nlocal_htlcs #colon;= 0\nremote_htlcs #colon;= 0
    FUNDED --> [*]: (28)\n? SHUTDOWN ||\n!SHUTDOWN

    %% Simple error case
    FUNDED --> FAIL_CHANNEL: (1)\n? UPDATE_ADD_HTLC\n--------------------------------\n! UPDATE_FAIL_HTLC ||\n! UPDATE_FAIL_MALFORMED_HTLC

    %% Received an update from upstream
    FUNDED --> MORE_HTLCS_WAIT: (2)\n? UPDATE_ADD_HTLC\n--------------------------------\nlocal_htlcs++\nset [new HTLCs timer]
    FUNDED --> MORE_HTLCS_WAIT: (3)\n? USER_TX ||\n? UPDATE_ADD_HTLC_DS\n--------------------------------\n! UPDATE_ADD_HTLC\nremote_htlcs++\nset [new HTLCs timer]
    FUNDED --> COMM_WAIT: (4)\n? USER_TX ||\n? UPDATE_ADD_HTLC_DS\n--------------------------------\n! UPDATE_ADD_HTLC\n ! COMMITMENT_SIGNED\nremote_htlcs++\nset [commitment/revocation timer]

    MORE_HTLCS_WAIT --> REVOKE_WAIT: (5)\n? COMMITMENT_SIGNED\n------------------------------------\n! REVOKE_AND_ACK\n! COMMITMENT_SIGNED\nset [revocation timer]
    MORE_HTLCS_WAIT --> COMM_WAIT: (6)\n? USER_TX ||\n? UPDATE_ADD_HTLC_DS\n--------------------------------\n! UPDATE_ADD_HTLC\n! COMMITMENT_SIGNED\nremote_htlcs++\nset [commitment/revocation timer]
    MORE_HTLCS_WAIT --> COMM_WAIT: (7)\n? UPDATE_ADD_HTLC\n--------------------------------\n! UPDATE_ADD_HTLC\n! COMMITMENT_SIGNED\nlocal_htlcs++\nremote_htlcs++\nset [commitment/revocation timer]

    %% NOTE: I'm actually not sure about this one. The implementation does it, but I don't think it's mentioned in the BOLTs
    MORE_HTLCS_WAIT --> COMM_WAIT: (8)\nTIMEOUT [new HTLCS timer]\n-----------------------------------\n! COMMITMENT_SIGNED\nset [commitment/revocation timer]
    MORE_HTLCS_WAIT --> FAIL_CHANNEL: (9)\n? UPDATE_FAIL_HTLC ||\n? UPDATE_FAIL_MALFORMED_HTLC
    MORE_HTLCS_WAIT --> MORE_HTLCS_WAIT: (10)\n? USER_TX ||\n? UPDATE_ADD_HTLC_DS\n--------------------------------\n! UPDATE_ADD_HTLC\nremote_htlcs++
    MORE_HTLCS_WAIT --> MORE_HTLCS_WAIT: (11)\n? UPDATE_ADD_HTLC\n--------------------------------\nlocal_htlcs++
    MORE_HTLCS_WAIT --> FAIL_CHANNEL: (12)\n? UPDATE_ADD_HTLC\n--------------------------------\n! UPDATE_FAIL_HTLC ||\n! UPDATE_FAIL_MALFORMED_HTLC

    REVOKE_WAIT --> COMM_WAIT_2: (13)\n? REVOKE_AND_ACK &&\nremote_htlcs==1 &&\nlocal_htlcs==0\n-------------------------------\n! UPDATE_FULFILL_HTLC\n! COMMITMENT_SIGNED\nset [commitment timer]
    REVOKE_WAIT --> FULFILL_WAIT: (14)\n? REVOKE_AND_ACK\n-------------------------------\nset [remote fulfillment timer]\nset [local fulfillment timer]
    REVOKE_WAIT --> FAIL_CHANNEL: (15)\n(TIMEOUT [revocation timer] && ! ERROR) || \nTIMEOUT ||\n? ERROR

    COMM_WAIT --> COMM_WAIT: (16)\n? REVOKE_AND_ACK 
    COMM_WAIT --> COMM_WAIT: (17)\n? COMMITMENT_SIGNED\n------------------------------------\n! REVOKE_AND_ACK
    COMM_WAIT --> FULFILL_WAIT: (18)\n? REVOKE_AND_ACK\n-------------------------------\nset [remote fulfillment timer]\nset [local fulfillment timer]
    COMM_WAIT --> FULFILL_WAIT: (19)\n? COMMITMENT_SIGNED\n------------------------------------\n! REVOKE_AND_ACK\nset [remote fulfillment timer]\nset [local fulfillment timer]
    COMM_WAIT --> FAIL_CHANNEL: (20)\n(TIMEOUT [commitment/revocation timer] && ! ERROR) || \nTIMEOUT [commitment/revocation timer] ||\n? ERROR

    FULFILL_WAIT --> FULFILL_WAIT: (21)\n? UPDATE_FULFILL_HTLC\n-------------------------------------\nlocal_htlcs--\nset [remote fulfillment timer]
    FULFILL_WAIT --> FULFILL_WAIT: (22)\n? UPDATE_FULFILL_HTLC_DS || TIMEOUT [local fulfillment timer]\n------------------------------------------------------------\n! UPDATE_FULFILL_HTLC\nremote_htlcs--
    FULFILL_WAIT --> FAIL_CHANNEL: (23)\n(TIMEOUT [remote fulfillment timer] && ! ERROR) || \nTIMEOUT [remote fulfillment timer] ||\n? ERROR

    FULFILL_WAIT --> COMM_WAIT_2: (24)\n? UPDATE_FULFILL_HTLC &&\nlocal_htlcs==1 &&\nremote_htlcs==0\n-------------------------------------\n! COMMITMENT_SIGNED\nlocal_htlcs--\nset [commitment timer]
    FULFILL_WAIT --> COMM_WAIT_2: (25)\n(? UPDATE_FULFILL_HTLC_DS || TIMEOUT) &&\nremote_htlcs==1 &&\nlocal_htlcs==0\n------------------------------------------------------------\n! UPDATE_FULFILL_HTLC\n! COMMITMENT_SIGNED\nremote_htlcs--\nset [commitment timer]

    COMM_WAIT_2 --> REVOKE_WAIT_2: (26)\n? COMMITMENT_SIGNED\n------------------------------------\n! REVOKE_AND_ACK\nset [revocation timer]
    COMM_WAIT_2 --> FAIL_CHANNEL: (27)\n(TIMEOUT [commitment timer] && ! ERROR) || \nTIMEOUT [commitment timer] ||\n? ERROR
    REVOKE_WAIT_2 --> FUNDED: (29)\n? REVOKE_AND_ACK
    REVOKE_WAIT_2 --> FAIL_CHANNEL: (30)\n(TIMEOUT [revocation timer] && ! ERROR) ||\nTIMEOUT [revocation timer] ||\n? ERROR
```
