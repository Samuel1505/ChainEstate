;; Governance Contract
;; Decentralized decision-making for property management

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u501))
(define-constant ERR-VOTING-NOT-ACTIVE (err u502))
(define-constant ERR-ALREADY-VOTED (err u503))
(define-constant ERR-INSUFFICIENT-SHARES (err u504))
(define-constant ERR-QUORUM-NOT-MET (err u505))
(define-constant ERR-PROPOSAL-NOT-PASSED (err u506))
(define-constant ERR-ALREADY-EXECUTED (err u507))
(define-constant ERR-VOTING-PERIOD-NOT-ENDED (err u508))

;; Proposal status constants
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-PASSED u2)
(define-constant STATUS-FAILED u3)
(define-constant STATUS-EXECUTED u4)
(define-constant STATUS-CANCELLED u5)

;; Vote options
(define-constant VOTE-YES u1)
(define-constant VOTE-NO u2)
(define-constant VOTE-ABSTAIN u3)

(use-trait share-token-trait .share-token-trait.share-token-trait)
(define-constant ERR-INVALID-TOKEN (err u509))

;; Governance parameters
(define-data-var min-proposal-threshold-bps uint u100) ;; 1% of shares required to propose
(define-data-var quorum-bps uint u3000) ;; 30% participation required
(define-data-var voting-period-blocks uint u2016) ;; ~14 days (assuming 10 min blocks)

;; Contract state
(define-data-var last-proposal-id uint u0)
(define-data-var access-control-contract principal tx-sender)

;; Proposal structure
(define-map proposals
  uint
  {
    property-id: uint,
    proposer: principal,
    title: (string-ascii 256),
    description: (string-ascii 1024),
    start-block: uint,
    end-block: uint,
    status: uint,
    yes-votes: uint,
    no-votes: uint,
    abstain-votes: uint,
    total-votes: uint,
    share-token-contract: principal,
    execution-data: (optional (buff 1024)),
  }
)

;; Vote tracking
(define-map votes
  {
    proposal-id: uint,
    voter: principal,
  }
  {
    vote: uint,
    voting-power: uint,
    vote-block: uint,
  }
)

;; Vote delegation
(define-map delegations
  {
    delegator: principal,
    property-id: uint,
  }
  principal
)

;; Helper functions

(define-private (is-admin)
  (contract-call? .access-control is-admin tx-sender)
)

(define-private (get-share-balance
    (token-contract <share-token-trait>)
    (investor principal)
  )
  (unwrap-panic (contract-call? token-contract get-balance investor))
)

(define-private (get-total-shares (token-contract <share-token-trait>))
  (unwrap-panic (contract-call? token-contract get-total-supply))
)

(define-private (calculate-threshold
    (total-shares uint)
    (threshold-bps uint)
  )
  (/ (* total-shares threshold-bps) u10000)
)

(define-private (has-voted
    (proposal-id uint)
    (voter principal)
  )
  (is-some (map-get? votes {
    proposal-id: proposal-id,
    voter: voter,
  }))
)

(define-private (get-delegate
    (delegator principal)
    (property-id uint)
  )
  (map-get? delegations {
    delegator: delegator,
    property-id: property-id,
  })
)

;; Read-only functions

(define-read-only (get-governance-parameters)
  (ok {
    min-proposal-threshold-bps: (var-get min-proposal-threshold-bps),
    quorum-bps: (var-get quorum-bps),
    voting-period-blocks: (var-get voting-period-blocks),
  })
)

(define-read-only (get-proposal (proposal-id uint))
  (ok (map-get? proposals proposal-id))
)

(define-read-only (get-vote
    (proposal-id uint)
    (voter principal)
  )
  (ok (map-get? votes {
    proposal-id: proposal-id,
    voter: voter,
  }))
)

(define-read-only (get-proposal-status (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal (ok (get status proposal))
    ERR-PROPOSAL-NOT-FOUND
  )
)

;; Public functions

(define-public (create-proposal
    (property-id uint)
    (title (string-ascii 256))
    (description (string-ascii 1024))
    (share-token-contract <share-token-trait>)
    (execution-data (optional (buff 1024)))
  )
  (let (
      (proposer-shares (get-share-balance share-token-contract tx-sender))
      (total-shares (get-total-shares share-token-contract))
      (min-shares-required (calculate-threshold total-shares (var-get min-proposal-threshold-bps)))
      (new-proposal-id (+ (var-get last-proposal-id) u1))
      (end-block (+ stacks-block-height (var-get voting-period-blocks)))
    )
    ;; Check proposer has minimum shares
    (asserts! (>= proposer-shares min-shares-required) ERR-INSUFFICIENT-SHARES)

    ;; Create proposal
    (map-set proposals new-proposal-id {
      property-id: property-id,
      proposer: tx-sender,
      title: title,
      description: description,
      start-block: stacks-block-height,
      end-block: end-block,
      status: STATUS-ACTIVE,
      yes-votes: u0,
      no-votes: u0,
      abstain-votes: u0,
      total-votes: u0,
      share-token-contract: (contract-of share-token-contract),
      execution-data: execution-data,
    })

    ;; Update last proposal ID
    (var-set last-proposal-id new-proposal-id)

    (print {
      event: "proposal-created",
      proposal-id: new-proposal-id,
      property-id: property-id,
      proposer: tx-sender,
      title: title,
      end-block: end-block,
    })

    (ok new-proposal-id)
  )
)

(define-public (cast-vote
    (proposal-id uint)
    (vote uint)
    (share-token-contract <share-token-trait>)
  )
  (let (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
      (voter-shares (get-share-balance share-token-contract tx-sender))
      (current-yes (get yes-votes proposal))
      (current-no (get no-votes proposal))
      (current-abstain (get abstain-votes proposal))
      (current-total (get total-votes proposal))
    )
    ;; Check token contract matches
    (asserts!
      (is-eq (contract-of share-token-contract)
        (get share-token-contract proposal)
      )
      ERR-INVALID-TOKEN
    )
    ;; Check proposal is active
    (asserts! (is-eq (get status proposal) STATUS-ACTIVE) ERR-VOTING-NOT-ACTIVE)

    ;; Check voting period hasn't ended
    (asserts! (< stacks-block-height (get end-block proposal)) ERR-VOTING-NOT-ACTIVE)

    ;; Check hasn't already voted
    (asserts! (not (has-voted proposal-id tx-sender)) ERR-ALREADY-VOTED)

    ;; Check has shares
    (asserts! (> voter-shares u0) ERR-INSUFFICIENT-SHARES)

    ;; Lock shares during voting (call share token contract)
    (try! (contract-call? share-token-contract lock-shares tx-sender voter-shares))

    ;; Record vote
    (map-set votes {
      proposal-id: proposal-id,
      voter: tx-sender,
    } {
      vote: vote,
      voting-power: voter-shares,
      vote-block: stacks-block-height,
    })

    ;; Update vote tallies
    (map-set proposals proposal-id
      (merge proposal {
        yes-votes: (if (is-eq vote VOTE-YES)
          (+ current-yes voter-shares)
          current-yes
        ),
        no-votes: (if (is-eq vote VOTE-NO)
          (+ current-no voter-shares)
          current-no
        ),
        abstain-votes: (if (is-eq vote VOTE-ABSTAIN)
          (+ current-abstain voter-shares)
          current-abstain
        ),
        total-votes: (+ current-total voter-shares),
      })
    )

    (print {
      event: "vote-cast",
      proposal-id: proposal-id,
      voter: tx-sender,
      vote: vote,
      voting-power: voter-shares,
    })

    (ok true)
  )
)

(define-public (execute-proposal
    (proposal-id uint)
    (share-token-contract <share-token-trait>)
  )
  (let (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
      (total-shares (get-total-shares share-token-contract))
      (quorum-required (calculate-threshold total-shares (var-get quorum-bps)))
    )
    ;; Check token contract matches
    (asserts!
      (is-eq (contract-of share-token-contract)
        (get share-token-contract proposal)
      )
      ERR-INVALID-TOKEN
    )
    ;; Check voting period has ended
    (asserts! (>= stacks-block-height (get end-block proposal))
      ERR-VOTING-PERIOD-NOT-ENDED
    )

    ;; Check not already executed
    (asserts! (not (is-eq (get status proposal) STATUS-EXECUTED))
      ERR-ALREADY-EXECUTED
    )

    ;; Check quorum met
    (asserts! (>= (get total-votes proposal) quorum-required) ERR-QUORUM-NOT-MET)

    ;; Check proposal passed
    (asserts! (> (get yes-votes proposal) (get no-votes proposal))
      ERR-PROPOSAL-NOT-PASSED
    )

    ;; Update status to executed
    (map-set proposals proposal-id (merge proposal { status: STATUS-EXECUTED }))

    (print {
      event: "proposal-executed",
      proposal-id: proposal-id,
      yes-votes: (get yes-votes proposal),
      no-votes: (get no-votes proposal),
      total-votes: (get total-votes proposal),
    })

    (ok true)
  )
)

(define-public (cancel-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND)))
    ;; Only proposer or admin can cancel
    (asserts! (or (is-eq tx-sender (get proposer proposal)) (is-admin))
      ERR-NOT-AUTHORIZED
    )

    ;; Can only cancel if still active
    (asserts! (is-eq (get status proposal) STATUS-ACTIVE) ERR-VOTING-NOT-ACTIVE)

    ;; Update status
    (map-set proposals proposal-id (merge proposal { status: STATUS-CANCELLED }))

    (print {
      event: "proposal-cancelled",
      proposal-id: proposal-id,
    })

    (ok true)
  )
)

(define-public (delegate-vote
    (property-id uint)
    (delegate principal)
  )
  (begin
    (map-set delegations {
      delegator: tx-sender,
      property-id: property-id,
    }
      delegate
    )

    (print {
      event: "vote-delegated",
      delegator: tx-sender,
      delegate: delegate,
      property-id: property-id,
    })

    (ok true)
  )
)

(define-public (revoke-delegation (property-id uint))
  (begin
    (map-delete delegations {
      delegator: tx-sender,
      property-id: property-id,
    })

    (print {
      event: "delegation-revoked",
      delegator: tx-sender,
      property-id: property-id,
    })

    (ok true)
  )
)

(define-public (update-governance-parameters
    (new-min-threshold-bps uint)
    (new-quorum-bps uint)
    (new-voting-period-blocks uint)
  )
  (begin
    ;; Only admin can update (or via governance itself)
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)

    (var-set min-proposal-threshold-bps new-min-threshold-bps)
    (var-set quorum-bps new-quorum-bps)
    (var-set voting-period-blocks new-voting-period-blocks)

    (print {
      event: "governance-parameters-updated",
      min-proposal-threshold-bps: new-min-threshold-bps,
      quorum-bps: new-quorum-bps,
      voting-period-blocks: new-voting-period-blocks,
    })

    (ok true)
  )
)
