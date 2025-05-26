;; Provider Verification Contract
;; Validates digital health companies and their credentials

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROVIDER_NOT_FOUND (err u101))
(define-constant ERR_PROVIDER_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Provider status types
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_REVOKED u3)

;; Provider data structure
(define-map providers
  { provider-id: principal }
  {
    company-name: (string-ascii 100),
    license-number: (string-ascii 50),
    specialization: (string-ascii 100),
    verification-status: uint,
    verified-at: uint,
    verified-by: principal
  }
)

;; Track total providers
(define-data-var total-providers uint u0)

;; Register a new provider
(define-public (register-provider
  (provider-id principal)
  (company-name (string-ascii 100))
  (license-number (string-ascii 50))
  (specialization (string-ascii 100)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? providers { provider-id: provider-id })) ERR_PROVIDER_ALREADY_EXISTS)

    (map-set providers
      { provider-id: provider-id }
      {
        company-name: company-name,
        license-number: license-number,
        specialization: specialization,
        verification-status: STATUS_PENDING,
        verified-at: u0,
        verified-by: tx-sender
      }
    )

    (var-set total-providers (+ (var-get total-providers) u1))
    (ok true)
  )
)

;; Verify a provider
(define-public (verify-provider (provider-id principal))
  (let ((provider-data (unwrap! (map-get? providers { provider-id: provider-id }) ERR_PROVIDER_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set providers
      { provider-id: provider-id }
      (merge provider-data {
        verification-status: STATUS_VERIFIED,
        verified-at: block-height,
        verified-by: tx-sender
      })
    )
    (ok true)
  )
)

;; Update provider status
(define-public (update-provider-status (provider-id principal) (new-status uint))
  (let ((provider-data (unwrap! (map-get? providers { provider-id: provider-id }) ERR_PROVIDER_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-status STATUS_REVOKED) ERR_INVALID_STATUS)

    (map-set providers
      { provider-id: provider-id }
      (merge provider-data { verification-status: new-status })
    )
    (ok true)
  )
)

;; Get provider information
(define-read-only (get-provider (provider-id principal))
  (map-get? providers { provider-id: provider-id })
)

;; Check if provider is verified
(define-read-only (is-provider-verified (provider-id principal))
  (match (map-get? providers { provider-id: provider-id })
    provider-data (is-eq (get verification-status provider-data) STATUS_VERIFIED)
    false
  )
)

;; Get total providers count
(define-read-only (get-total-providers)
  (var-get total-providers)
)
