;; Legacy Documentation Contract
;; Manages consciousness legacy recording and storage

(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_LEGACY_NOT_FOUND (err u201))
(define-constant ERR_INVALID_PROVIDER (err u202))
(define-constant ERR_LEGACY_EXISTS (err u203))

;; Legacy status constants
(define-constant STATUS_RECORDING u0)
(define-constant STATUS_COMPLETED u1)
(define-constant STATUS_VERIFIED u2)
(define-constant STATUS_ARCHIVED u3)

;; Data structures
(define-map legacy-records
  { legacy-id: uint }
  {
    elder-id: principal,
    provider-id: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    content-hash: (string-ascii 64),
    creation-date: uint,
    status: uint,
    privacy-level: uint,
    cultural-tags: (list 10 (string-ascii 50))
  }
)

(define-map elder-legacies
  { elder-id: principal }
  { legacy-ids: (list 50 uint) }
)

(define-data-var next-legacy-id uint u1)

;; Create a new legacy record
(define-public (create-legacy (elder-id principal)
                             (provider-id principal)
                             (title (string-ascii 100))
                             (description (string-ascii 500))
                             (content-hash (string-ascii 64))
                             (privacy-level uint)
                             (cultural-tags (list 10 (string-ascii 50))))
  (let ((legacy-id (var-get next-legacy-id)))
    ;; Verify provider is authorized (simplified check)
    (asserts! (not (is-eq provider-id elder-id)) ERR_INVALID_PROVIDER)

    ;; Create legacy record
    (map-set legacy-records
      { legacy-id: legacy-id }
      {
        elder-id: elder-id,
        provider-id: provider-id,
        title: title,
        description: description,
        content-hash: content-hash,
        creation-date: block-height,
        status: STATUS_RECORDING,
        privacy-level: privacy-level,
        cultural-tags: cultural-tags
      }
    )

    ;; Update elder's legacy list
    (match (map-get? elder-legacies { elder-id: elder-id })
      existing-legacies
      (map-set elder-legacies
        { elder-id: elder-id }
        { legacy-ids: (unwrap! (as-max-len? (append (get legacy-ids existing-legacies) legacy-id) u50) ERR_LEGACY_EXISTS) }
      )
      (map-set elder-legacies
        { elder-id: elder-id }
        { legacy-ids: (list legacy-id) }
      )
    )

    (var-set next-legacy-id (+ legacy-id u1))
    (ok legacy-id)
  )
)

;; Complete legacy recording
(define-public (complete-legacy (legacy-id uint))
  (match (map-get? legacy-records { legacy-id: legacy-id })
    legacy-data
    (begin
      (asserts! (or (is-eq tx-sender (get elder-id legacy-data))
                    (is-eq tx-sender (get provider-id legacy-data))) ERR_UNAUTHORIZED)
      (map-set legacy-records
        { legacy-id: legacy-id }
        (merge legacy-data { status: STATUS_COMPLETED })
      )
      (ok true)
    )
    ERR_LEGACY_NOT_FOUND
  )
)

;; Verify legacy content
(define-public (verify-legacy (legacy-id uint))
  (match (map-get? legacy-records { legacy-id: legacy-id })
    legacy-data
    (begin
      (asserts! (is-eq tx-sender (get provider-id legacy-data)) ERR_UNAUTHORIZED)
      (map-set legacy-records
        { legacy-id: legacy-id }
        (merge legacy-data { status: STATUS_VERIFIED })
      )
      (ok true)
    )
    ERR_LEGACY_NOT_FOUND
  )
)

;; Get legacy record
(define-read-only (get-legacy (legacy-id uint))
  (map-get? legacy-records { legacy-id: legacy-id })
)

;; Get elder's legacies
(define-read-only (get-elder-legacies (elder-id principal))
  (map-get? elder-legacies { elder-id: elder-id })
)

;; Get legacy count
(define-read-only (get-legacy-count)
  (var-get next-legacy-id)
)
