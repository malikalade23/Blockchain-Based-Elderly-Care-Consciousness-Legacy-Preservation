;; Care Provider Verification Contract
;; Validates and manages consciousness legacy preservation service providers

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROVIDER_EXISTS (err u101))
(define-constant ERR_PROVIDER_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Provider status constants
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_SUSPENDED u2)

;; Data structures
(define-map care-providers
  { provider-id: principal }
  {
    name: (string-ascii 100),
    credentials: (string-ascii 200),
    specialization: (string-ascii 100),
    status: uint,
    verification-date: uint,
    rating: uint
  }
)

(define-map provider-stats
  { provider-id: principal }
  {
    total-legacies: uint,
    successful-transmissions: uint,
    family-connections: uint
  }
)

(define-data-var next-provider-id uint u1)

;; Register a new care provider
(define-public (register-provider (name (string-ascii 100))
                                 (credentials (string-ascii 200))
                                 (specialization (string-ascii 100)))
  (let ((provider-id tx-sender))
    (asserts! (is-none (map-get? care-providers { provider-id: provider-id })) ERR_PROVIDER_EXISTS)
    (map-set care-providers
      { provider-id: provider-id }
      {
        name: name,
        credentials: credentials,
        specialization: specialization,
        status: STATUS_PENDING,
        verification-date: block-height,
        rating: u0
      }
    )
    (map-set provider-stats
      { provider-id: provider-id }
      {
        total-legacies: u0,
        successful-transmissions: u0,
        family-connections: u0
      }
    )
    (ok provider-id)
  )
)

;; Verify a care provider (only contract owner)
(define-public (verify-provider (provider-id principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? care-providers { provider-id: provider-id })
      provider-data
      (begin
        (map-set care-providers
          { provider-id: provider-id }
          (merge provider-data { status: STATUS_VERIFIED, verification-date: block-height })
        )
        (ok true)
      )
      ERR_PROVIDER_NOT_FOUND
    )
  )
)

;; Update provider rating
(define-public (update-provider-rating (provider-id principal) (new-rating uint))
  (begin
    (asserts! (and (>= new-rating u1) (<= new-rating u5)) ERR_INVALID_STATUS)
    (match (map-get? care-providers { provider-id: provider-id })
      provider-data
      (begin
        (map-set care-providers
          { provider-id: provider-id }
          (merge provider-data { rating: new-rating })
        )
        (ok true)
      )
      ERR_PROVIDER_NOT_FOUND
    )
  )
)

;; Get provider information
(define-read-only (get-provider (provider-id principal))
  (map-get? care-providers { provider-id: provider-id })
)

;; Get provider statistics
(define-read-only (get-provider-stats (provider-id principal))
  (map-get? provider-stats { provider-id: provider-id })
)

;; Check if provider is verified
(define-read-only (is-provider-verified (provider-id principal))
  (match (map-get? care-providers { provider-id: provider-id })
    provider-data (is-eq (get status provider-data) STATUS_VERIFIED)
    false
  )
)
