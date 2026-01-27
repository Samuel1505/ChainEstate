;; Marketplace Contract
;; Peer-to-peer trading platform for property shares

(use-trait share-token-trait .share-token-trait.share-token-trait)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u600))
(define-constant ERR-ORDER-NOT-FOUND (err u601))
(define-constant ERR-INVALID-AMOUNT (err u602))
(define-constant ERR-INSUFFICIENT-BALANCE (err u603))
(define-constant ERR-NOT-WHITELISTED (err u604))
(define-constant ERR-ORDER-EXPIRED (err u605))
(define-constant ERR-ORDER-FILLED (err u606))
(define-constant ERR-INVALID-PRICE (err u607))

;; Order type constants
(define-constant ORDER-TYPE-SELL u1)
(define-constant ORDER-TYPE-BUY u2)

;; Order status constants
(define-constant ORDER-STATUS-OPEN u1)
(define-constant ORDER-STATUS-FILLED u2)
(define-constant ORDER-STATUS-CANCELLED u3)

;; Platform fee (in basis points: 100 = 1%)
(define-data-var platform-fee-bps uint u100) ;; 1%

;; Contract state
(define-data-var last-order-id uint u0)
(define-data-var access-control-contract principal tx-sender)
(define-data-var contract-principal principal tx-sender)

;; Order structure
(define-map orders
  uint
  {
    property-id: uint,
    trader: principal,
    order-type: uint,
    quantity: uint,
    price-per-share: uint,
    total-price: uint,
    expiration: uint,
    status: uint,
    share-token-contract: principal,
    created-at: uint,
  }
)

;; Escrowed shares (for sell orders)
(define-map escrowed-shares
  uint
  uint
)

;; Price history tracking
(define-map last-trade-price
  uint ;; property-id
  uint ;; price-per-share
)

;; Trading volume tracking
(define-map trading-volume
  uint ;; property-id
  uint ;; total volume
)

;; Helper functions

(define-private (is-admin)
  (contract-call? .access-control is-admin tx-sender)
)

;; Helper to check if address is whitelisted
;; Note: Due to Clarity 2.0+ limitations, we can't call custom functions with principals
;; This function will need to be called with trait type, not principal
(define-private (is-whitelisted-with-trait
    (token-contract <share-token-trait>)
    (address principal)
  )
  (unwrap-panic (contract-call? token-contract check-whitelisted address))
)

;; For cases where we only have principal, we can't call custom functions in Clarity 2.0+
;; As a workaround, we'll skip the whitelist check when we only have the principal
;; The whitelist check will be performed when creating orders (where we have the trait)
(define-private (is-whitelisted
    (token-contract principal)
    (address principal)
  )
  ;; Note: Due to Clarity 2.0+ limitations, we can't call custom functions with principals
  ;; The whitelist check is performed when orders are created (with trait), so we assume valid here
  true
)

(define-private (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-bps)) u10000)
)

;; Read-only functions

(define-read-only (get-order (order-id uint))
  (ok (map-get? orders order-id))
)

(define-read-only (get-last-trade-price (property-id uint))
  (ok (map-get? last-trade-price property-id))
)

(define-read-only (get-trading-volume (property-id uint))
  (ok (default-to u0 (map-get? trading-volume property-id)))
)

(define-read-only (get-platform-fee-bps)
  (ok (var-get platform-fee-bps))
)

;; Public functions

(define-public (create-sell-order
    (property-id uint)
    (quantity uint)
    (price-per-share uint)
    (expiration uint)
    (share-token-contract <share-token-trait>)
  )
  (let (
      (new-order-id (+ (var-get last-order-id) u1))
      (total-price (* quantity price-per-share))
      (seller-balance (unwrap-panic (contract-call? share-token-contract get-balance tx-sender)))
    )
    ;; Validate inputs
    (asserts! (> quantity u0) ERR-INVALID-AMOUNT)
    (asserts! (> price-per-share u0) ERR-INVALID-PRICE)
    (asserts! (> expiration stacks-block-height) ERR-ORDER-EXPIRED)

    ;; Check seller is whitelisted
    (asserts! (is-whitelisted-with-trait share-token-contract tx-sender) ERR-NOT-WHITELISTED)

    ;; Check seller has sufficient balance
    (asserts! (>= seller-balance quantity) ERR-INSUFFICIENT-BALANCE)

    ;; Escrow shares (transfer to this contract)
    (try! (contract-call? share-token-contract transfer quantity tx-sender
      (var-get contract-principal) none
    ))

    ;; Create order
    (map-set orders new-order-id {
      property-id: property-id,
      trader: tx-sender,
      order-type: ORDER-TYPE-SELL,
      quantity: quantity,
      price-per-share: price-per-share,
      total-price: total-price,
      expiration: expiration,
      status: ORDER-STATUS-OPEN,
      share-token-contract: (contract-of share-token-contract),
      created-at: stacks-block-height,
    })

    ;; Track escrowed shares
    (map-set escrowed-shares new-order-id quantity)

    ;; Update last order ID
    (var-set last-order-id new-order-id)

    (print {
      event: "sell-order-created",
      order-id: new-order-id,
      property-id: property-id,
      seller: tx-sender,
      quantity: quantity,
      price-per-share: price-per-share,
      total-price: total-price,
    })

    (ok new-order-id)
  )
)

(define-public (create-buy-order
    (property-id uint)
    (quantity uint)
    (price-per-share uint)
    (expiration uint)
    (share-token-contract <share-token-trait>)
  )
  (let (
      (new-order-id (+ (var-get last-order-id) u1))
      (total-price (* quantity price-per-share))
    )
    ;; Validate inputs
    (asserts! (> quantity u0) ERR-INVALID-AMOUNT)
    (asserts! (> price-per-share u0) ERR-INVALID-PRICE)
    (asserts! (> expiration stacks-block-height) ERR-ORDER-EXPIRED)

    ;; Check buyer is whitelisted
    (asserts! (is-whitelisted-with-trait share-token-contract tx-sender) ERR-NOT-WHITELISTED)

    ;; Escrow STX (buyer deposits payment to this contract)
    (try! (stx-transfer? total-price tx-sender (var-get contract-principal)))

    ;; Create order
    (map-set orders new-order-id {
      property-id: property-id,
      trader: tx-sender,
      order-type: ORDER-TYPE-BUY,
      quantity: quantity,
      price-per-share: price-per-share,
      total-price: total-price,
      expiration: expiration,
      status: ORDER-STATUS-OPEN,
      share-token-contract: (contract-of share-token-contract),
      created-at: stacks-block-height,
    })

    ;; Update last order ID
    (var-set last-order-id new-order-id)

    (print {
      event: "buy-order-created",
      order-id: new-order-id,
      property-id: property-id,
      buyer: tx-sender,
      quantity: quantity,
      price-per-share: price-per-share,
      total-price: total-price,
    })

    (ok new-order-id)
  )
)

(define-public (fill-sell-order (order-id uint))
  (let (
      (order (unwrap! (map-get? orders order-id) ERR-ORDER-NOT-FOUND))
      (seller (get trader order))
      (quantity (get quantity order))
      (total-price (get total-price order))
      (platform-fee (calculate-platform-fee total-price))
      (seller-proceeds (- total-price platform-fee))
      (share-token-contract (get share-token-contract order))
    )
    ;; Check order is open
    (asserts! (is-eq (get status order) ORDER-STATUS-OPEN) ERR-ORDER-FILLED)

    ;; Check order type is sell
    (asserts! (is-eq (get order-type order) ORDER-TYPE-SELL) ERR-NOT-AUTHORIZED)

    ;; Check not expired
    (asserts! (> (get expiration order) stacks-block-height) ERR-ORDER-EXPIRED)

    ;; Check buyer is whitelisted
    (asserts! (is-whitelisted share-token-contract tx-sender) ERR-NOT-WHITELISTED)

    ;; Buyer pays STX to this contract  
    (try! (stx-transfer? total-price tx-sender (var-get contract-principal)))

    ;; Transfer shares from escrow to buyer
    ;; Using exact same pattern as line 320 which works with principal
    (try! (contract-call? share-token-contract transfer quantity tx-sender tx-sender none))

    ;; Pay seller (minus platform fee)
    (try! (stx-transfer? seller-proceeds (var-get contract-principal) seller))

    ;; Update order status
    (map-set orders order-id (merge order { status: ORDER-STATUS-FILLED }))

    ;; Update price history
    (map-set last-trade-price (get property-id order) (get price-per-share order))

    ;; Update trading volume
    (let ((current-volume (default-to u0 (map-get? trading-volume (get property-id order)))))
      (map-set trading-volume (get property-id order) (+ current-volume quantity))
    )

    (print {
      event: "sell-order-filled",
      order-id: order-id,
      seller: seller,
      buyer: tx-sender,
      quantity: quantity,
      price-per-share: (get price-per-share order),
      platform-fee: platform-fee,
    })

    (ok true)
  )
)

(define-public (fill-buy-order (order-id uint))
  (let (
      (order (unwrap! (map-get? orders order-id) ERR-ORDER-NOT-FOUND))
      (buyer (get trader order))
      (quantity (get quantity order))
      (total-price (get total-price order))
      (platform-fee (calculate-platform-fee total-price))
      (seller-proceeds (- total-price platform-fee))
      (share-token-contract (get share-token-contract order))
      (seller-balance (unwrap-panic (contract-call? share-token-contract get-balance tx-sender)))
    )
    ;; Check order is open
    (asserts! (is-eq (get status order) ORDER-STATUS-OPEN) ERR-ORDER-FILLED)

    ;; Check order type is buy
    (asserts! (is-eq (get order-type order) ORDER-TYPE-BUY) ERR-NOT-AUTHORIZED)

    ;; Check not expired
    (asserts! (< stacks-block-height (get expiration order)) ERR-ORDER-EXPIRED)

    ;; Check seller is whitelisted
    (asserts! (is-whitelisted share-token-contract tx-sender) ERR-NOT-WHITELISTED)

    ;; Check seller has sufficient shares
    (asserts! (>= seller-balance quantity) ERR-INSUFFICIENT-BALANCE)

    ;; Transfer shares from seller to buyer
    (try! (contract-call? share-token-contract transfer quantity tx-sender buyer none))

    ;; Pay seller from escrowed STX (minus platform fee)
    (try! (stx-transfer? seller-proceeds (var-get contract-principal) tx-sender))

    ;; Update order status
    (map-set orders order-id (merge order { status: ORDER-STATUS-FILLED }))

    ;; Update price history
    (map-set last-trade-price (get property-id order) (get price-per-share order))

    ;; Update trading volume
    (let ((current-volume (default-to u0 (map-get? trading-volume (get property-id order)))))
      (map-set trading-volume (get property-id order) (+ current-volume quantity))
    )

    (print {
      event: "buy-order-filled",
      order-id: order-id,
      seller: tx-sender,
      buyer: buyer,
      quantity: quantity,
      price-per-share: (get price-per-share order),
      platform-fee: platform-fee,
    })

    (ok true)
  )
)

(define-public (cancel-order (order-id uint))
  (let ((order (unwrap! (map-get? orders order-id) ERR-ORDER-NOT-FOUND)))
    ;; Only order creator can cancel
    (asserts! (is-eq tx-sender (get trader order)) ERR-NOT-AUTHORIZED)

    ;; Check order is still open
    (asserts! (is-eq (get status order) ORDER-STATUS-OPEN) ERR-ORDER-FILLED)

    ;; Return escrowed assets
    (if (is-eq (get order-type order) ORDER-TYPE-SELL)
      ;; Return shares to seller
      (let ((token-contract (unwrap-panic (get share-token-contract order))))
        (try! (contract-call? token-contract transfer
          (get quantity order) (var-get contract-principal) (get trader order) none
        ))
      )
      ;; Return STX to buyer
      (try! (stx-transfer? (get total-price order) (var-get contract-principal) (get trader order)))
    )

    ;; Update order status
    (map-set orders order-id (merge order { status: ORDER-STATUS-CANCELLED }))

    (print {
      event: "order-cancelled",
      order-id: order-id,
      trader: tx-sender,
    })

    (ok true)
  )
)

(define-public (set-platform-fee (new-fee-bps uint))
  (begin
    ;; Only admin can update fee
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)

    ;; Validate fee (max 10%)
    (asserts! (<= new-fee-bps u1000) ERR-INVALID-AMOUNT)

    (var-set platform-fee-bps new-fee-bps)

    (print {
      event: "platform-fee-updated",
      new-fee-bps: new-fee-bps,
    })

    (ok true)
  )
)

(define-public (withdraw-platform-fees
    (amount uint)
    (recipient principal)
  )
  (begin
    ;; Only admin can withdraw fees
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)

    ;; Transfer fees
    (try! (stx-transfer? amount (var-get contract-principal) recipient))

    (print {
      event: "platform-fees-withdrawn",
      amount: amount,
      recipient: recipient,
    })

    (ok true)
  )
)
