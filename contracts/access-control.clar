;; Access Control Contract
;; Role-based permission system for ChainEstate platform

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-ROLE (err u101))
(define-constant ERR-ALREADY-HAS-ROLE (err u102))
(define-constant ERR-DOES-NOT-HAVE-ROLE (err u103))

;; Role constants
(define-constant ROLE-ADMIN u1)
(define-constant ROLE-PROPERTY-MANAGER u2)
(define-constant ROLE-KYC-VERIFIER u3)
(define-constant ROLE-ARBITER u4)

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Role assignments: (principal, role) -> bool
(define-map roles { user: principal, role: uint } bool)

;; Initialize contract owner with admin role
(map-set roles { user: tx-sender, role: ROLE-ADMIN } true)

;; Read-only functions

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

(define-read-only (has-role (user principal) (role uint))
  (default-to false (map-get? roles { user: user, role: role }))
)

(define-read-only (is-admin (user principal))
  (has-role user ROLE-ADMIN)
)

(define-read-only (is-property-manager (user principal))
  (has-role user ROLE-PROPERTY-MANAGER)
)

(define-read-only (is-kyc-verifier (user principal))
  (has-role user ROLE-KYC-VERIFIER)
)

(define-read-only (is-arbiter (user principal))
  (has-role user ROLE-ARBITER)
)

;; Private functions

(define-private (is-valid-role (role uint))
  (or 
    (is-eq role ROLE-ADMIN)
    (or
      (is-eq role ROLE-PROPERTY-MANAGER)
      (or
        (is-eq role ROLE-KYC-VERIFIER)
        (is-eq role ROLE-ARBITER)
      )
    )
  )
)

;; Public functions

(define-public (grant-role (user principal) (role uint))
  (begin
    ;; Only admin can grant roles
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    ;; Validate role
    (asserts! (is-valid-role role) ERR-INVALID-ROLE)
    ;; Check if user already has role
    (asserts! (not (has-role user role)) ERR-ALREADY-HAS-ROLE)
    ;; Grant role
    (ok (map-set roles { user: user, role: role } true))
  )
)

(define-public (revoke-role (user principal) (role uint))
  (begin
    ;; Only admin can revoke roles
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    ;; Validate role
    (asserts! (is-valid-role role) ERR-INVALID-ROLE)
    ;; Check if user has role
    (asserts! (has-role user role) ERR-DOES-NOT-HAVE-ROLE)
    ;; Cannot revoke own admin role if you're the contract owner
    (asserts! (not (and (is-eq user tx-sender) (is-eq role ROLE-ADMIN) (is-eq user (var-get contract-owner)))) ERR-NOT-AUTHORIZED)
    ;; Revoke role
    (ok (map-delete roles { user: user, role: role }))
  )
)

(define-public (renounce-role (role uint))
  (begin
    ;; Validate role
    (asserts! (is-valid-role role) ERR-INVALID-ROLE)
    ;; Check if user has role
    (asserts! (has-role tx-sender role) ERR-DOES-NOT-HAVE-ROLE)
    ;; Cannot renounce admin role if you're the contract owner
    (asserts! (not (and (is-eq role ROLE-ADMIN) (is-eq tx-sender (var-get contract-owner)))) ERR-NOT-AUTHORIZED)
    ;; Renounce role
    (ok (map-delete roles { user: tx-sender, role: role }))
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    ;; Only current owner can transfer ownership
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    ;; Grant admin role to new owner
    (try! (grant-role new-owner ROLE-ADMIN))
    ;; Update contract owner
    (var-set contract-owner new-owner)
    (ok true)
  )
)
