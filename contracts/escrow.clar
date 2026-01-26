;; Escrow Contract
;; Secure transaction handling for share purchases and property sales

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u700))
(define-constant ERR-ESCROW-NOT-FOUND (err u701))
(define-constant ERR-INVALID-AMOUNT (err u702))
(define-constant ERR-ESCROW-EXPIRED (err u703))
(define-constant ERR-ESCROW-COMPLETED (err u704))
(define-constant ERR-INSUFFICIENT-FUNDS (err u705))
(define-constant ERR-INVALID-STATUS (err u706))

;; Escrow type constants
(define-constant ESCROW-TYPE-SHARE-PURCHASE u1)
(define-constant ESCROW-TYPE-PROPERTY-SALE u2)

;; Escrow status constants
(define-constant STATUS-PENDING u1)
(define-constant STATUS-VERIFIED u2)
(define-constant STATUS-COMPLETED u3)
(define-constant STATUS-REFUNDED u4)
(define-constant STATUS-DISPUTED u5)

;; Contract state
(define-data-var last-escrow-id uint u0)
(define-data-var access-control-contract principal tx-sender)

;; Escrow structure
(define-map escrows
  uint
  {
    escrow-type: uint,
    property-id: uint,
    buyer: principal,
    seller: (optional principal),
    amount: uint,
    share-quantity: uint,
    share-token-contract: (optional principal),
    status: uint,
    created-at: uint,
    expiration: uint,
    arbiter: (optional principal)
  }
)

;; Helper functions

(define-private (is-admin)
  (contract-call? .access-control is-admin tx-sender)
)

(define-private (is-arbiter)
  (contract-call? .access-control is-arbiter tx-sender)
)

(define-private (is-kyc-verifier)
  (contract-call? .access-control is-kyc-verifier tx-sender)
)

;; Read-only functions

(define-read-only (get-escrow (escrow-id uint))
  (ok (map-get? escrows escrow-id))
)

(define-read-only (get-escrow-status (escrow-id uint))
  (match (map-get? escrows escrow-id)
    escrow (ok (get status escrow))
    ERR-ESCROW-NOT-FOUND
  )
)

;; Public functions

(define-public (initiate-share-purchase
    (property-id uint)
    (share-quantity uint)
    (price-per-share uint)
    (share-token-contract principal)
    (expiration uint)
  )
  (let
    (
      (new-escrow-id (+ (var-get last-escrow-id) u1))
      (total-amount (* share-quantity price-per-share))
      (contract-principal (as-contract tx-sender))
    )
    ;; Validate inputs
    (asserts! (> share-quantity u0) ERR-INVALID-AMOUNT)
    (asserts! (> price-per-share u0) ERR-INVALID-AMOUNT)
    (asserts! (> expiration block-height) ERR-ESCROW-EXPIRED)
    
    ;; Buyer deposits STX to escrow
    (try! (stx-transfer? total-amount tx-sender contract-principal))
    
    ;; Create escrow
    (map-set escrows new-escrow-id {
      escrow-type: ESCROW-TYPE-SHARE-PURCHASE,
      property-id: property-id,
      buyer: tx-sender,
      seller: none,
      amount: total-amount,
      share-quantity: share-quantity,
      share-token-contract: (some share-token-contract),
      status: STATUS-PENDING,
      created-at: block-height,
      expiration: expiration,
      arbiter: none
    })
    
    ;; Update last escrow ID
    (var-set last-escrow-id new-escrow-id)
    
    (print {
      event: "share-purchase-initiated",
      escrow-id: new-escrow-id,
      buyer: tx-sender,
      property-id: property-id,
      share-quantity: share-quantity,
      amount: total-amount
    })
    
    (ok new-escrow-id)
  )
)

(define-public (initiate-property-sale
    (property-id uint)
    (purchase-price uint)
    (seller principal)
    (expiration uint)
  )
  (let
    (
      (new-escrow-id (+ (var-get last-escrow-id) u1))
      (contract-principal (as-contract tx-sender))
    )
    ;; Validate inputs
    (asserts! (> purchase-price u0) ERR-INVALID-AMOUNT)
    (asserts! (> expiration block-height) ERR-ESCROW-EXPIRED)
    
    ;; Buyer deposits full purchase price
    (try! (stx-transfer? purchase-price tx-sender contract-principal))
    
    ;; Create escrow
    (map-set escrows new-escrow-id {
      escrow-type: ESCROW-TYPE-PROPERTY-SALE,
      property-id: property-id,
      buyer: tx-sender,
      seller: (some seller),
      amount: purchase-price,
      share-quantity: u0,
      share-token-contract: none,
      status: STATUS-PENDING,
      created-at: block-height,
      expiration: expiration,
      arbiter: none
    })
    
    ;; Update last escrow ID
    (var-set last-escrow-id new-escrow-id)
    
    (print {
      event: "property-sale-initiated",
      escrow-id: new-escrow-id,
      buyer: tx-sender,
      seller: seller,
      property-id: property-id,
      amount: purchase-price
    })
    
    (ok new-escrow-id)
  )
)

(define-public (verify-escrow (escrow-id uint))
  (let
    (
      (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
    )
    ;; Only KYC verifier or admin can verify
    (asserts! (or (is-kyc-verifier) (is-admin)) ERR-NOT-AUTHORIZED)
    
    ;; Check escrow is pending
    (asserts! (is-eq (get status escrow) STATUS-PENDING) ERR-INVALID-STATUS)
    
    ;; Check not expired
    (asserts! (< block-height (get expiration escrow)) ERR-ESCROW-EXPIRED)
    
    ;; Update status to verified
    (map-set escrows escrow-id (merge escrow { status: STATUS-VERIFIED }))
    
    (print {
      event: "escrow-verified",
      escrow-id: escrow-id,
      verifier: tx-sender
    })
    
    (ok true)
  )
)

(define-public (release-funds (escrow-id uint))
  (let
    (
      (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
    )
    ;; Only admin or arbiter can release funds
    (asserts! (or (is-admin) (is-arbiter)) ERR-NOT-AUTHORIZED)
    
    ;; Check escrow is verified
    (asserts! (is-eq (get status escrow) STATUS-VERIFIED) ERR-INVALID-STATUS)
    
    ;; Handle based on escrow type
    (if (is-eq (get escrow-type escrow) ESCROW-TYPE-SHARE-PURCHASE)
      ;; Share purchase: transfer shares to buyer
      (begin
        (try! (as-contract 
          (contract-call? 
            (unwrap-panic (get share-token-contract escrow))
            transfer 
            (get share-quantity escrow)
            tx-sender
            (get buyer escrow)
            none
          )
        ))
        ;; Payment goes to platform treasury (already escrowed)
        true
      )
      ;; Property sale: distribute funds to shareholders
      (begin
        ;; Transfer funds to seller (in real implementation, would distribute to all shareholders)
        (try! (as-contract 
          (stx-transfer? 
            (get amount escrow)
            tx-sender
            (unwrap-panic (get seller escrow))
          )
        ))
        true
      )
    )
    
    ;; Update status to completed
    (map-set escrows escrow-id (merge escrow { status: STATUS-COMPLETED }))
    
    (print {
      event: "escrow-completed",
      escrow-id: escrow-id,
      escrow-type: (get escrow-type escrow),
      amount: (get amount escrow)
    })
    
    (ok true)
  )
)

(define-public (refund-buyer (escrow-id uint))
  (let
    (
      (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
    )
    ;; Only admin or arbiter can refund
    (asserts! (or (is-admin) (is-arbiter)) ERR-NOT-AUTHORIZED)
    
    ;; Check escrow is not already completed
    (asserts! (not (is-eq (get status escrow) STATUS-COMPLETED)) ERR-ESCROW-COMPLETED)
    
    ;; Refund STX to buyer
    (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get buyer escrow))))
    
    ;; Update status to refunded
    (map-set escrows escrow-id (merge escrow { status: STATUS-REFUNDED }))
    
    (print {
      event: "escrow-refunded",
      escrow-id: escrow-id,
      buyer: (get buyer escrow),
      amount: (get amount escrow)
    })
    
    (ok true)
  )
)

(define-public (dispute-escrow (escrow-id uint) (arbiter principal))
  (let
    (
      (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
    )
    ;; Only buyer or seller can initiate dispute
    (asserts! 
      (or 
        (is-eq tx-sender (get buyer escrow))
        (is-eq (some tx-sender) (get seller escrow))
      )
      ERR-NOT-AUTHORIZED
    )
    
    ;; Check escrow is not completed or refunded
    (asserts! 
      (and 
        (not (is-eq (get status escrow) STATUS-COMPLETED))
        (not (is-eq (get status escrow) STATUS-REFUNDED))
      )
      ERR-INVALID-STATUS
    )
    
    ;; Update status to disputed and assign arbiter
    (map-set escrows escrow-id 
      (merge escrow { 
        status: STATUS-DISPUTED,
        arbiter: (some arbiter)
      })
    )
    
    (print {
      event: "escrow-disputed",
      escrow-id: escrow-id,
      arbiter: arbiter,
      initiated-by: tx-sender
    })
    
    (ok true)
  )
)

(define-public (resolve-dispute (escrow-id uint) (release-to-buyer bool))
  (let
    (
      (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
    )
    ;; Only assigned arbiter can resolve
    (asserts! 
      (is-eq (some tx-sender) (get arbiter escrow))
      ERR-NOT-AUTHORIZED
    )
    
    ;; Check escrow is disputed
    (asserts! (is-eq (get status escrow) STATUS-DISPUTED) ERR-INVALID-STATUS)
    
    ;; Resolve based on arbiter decision
    (if release-to-buyer
      ;; Refund to buyer
      (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get buyer escrow))))
      ;; Release to seller (if property sale)
      (if (is-some (get seller escrow))
        (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (unwrap-panic (get seller escrow)))))
        false
      )
    )
    
    ;; Update status
    (map-set escrows escrow-id 
      (merge escrow { 
        status: (if release-to-buyer STATUS-REFUNDED STATUS-COMPLETED)
      })
    )
    
    (print {
      event: "dispute-resolved",
      escrow-id: escrow-id,
      arbiter: tx-sender,
      release-to-buyer: release-to-buyer
    })
    
    (ok true)
  )
)

(define-public (cancel-expired-escrow (escrow-id uint))
  (let
    (
      (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
    )
    ;; Check escrow has expired
    (asserts! (>= block-height (get expiration escrow)) ERR-ESCROW-EXPIRED)
    
    ;; Check not already completed
    (asserts! (not (is-eq (get status escrow) STATUS-COMPLETED)) ERR-ESCROW-COMPLETED)
    
    ;; Auto-refund to buyer
    (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get buyer escrow))))
    
    ;; Update status
    (map-set escrows escrow-id (merge escrow { status: STATUS-REFUNDED }))
    
    (print {
      event: "escrow-expired-and-refunded",
      escrow-id: escrow-id,
      buyer: (get buyer escrow)
    })
    
    (ok true)
  )
)
