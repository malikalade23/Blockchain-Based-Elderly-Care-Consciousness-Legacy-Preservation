;; Wisdom Transmission Contract
;; Handles the transmission of consciousness legacy wisdom

(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_TRANSMISSION_NOT_FOUND (err u301))
(define-constant ERR_INVALID_RECIPIENT (err u302))
(define-constant ERR_LEGACY_NOT_ACCESSIBLE (err u303))

;; Transmission status constants
(define-constant STATUS_PENDING u0)
(define-constant STATUS_ACTIVE u1)
(define-constant STATUS_COMPLETED u2)
(define-constant STATUS_EXPIRED u3)

;; Data structures
(define-map wisdom-transmissions
  { transmission-id: uint }
  {
    legacy-id: uint,
    transmitter-id: principal,
    recipient-id: principal,
    transmission-method: (string-ascii 50),
    scheduled-date: uint,
    completion-date: (optional uint),
    status: uint,
    notes: (string-ascii 300)
  }
)

(define-map recipient-transmissions
  { recipient-id: principal }
  { transmission-ids: (list 100 uint) }
)

(define-map transmission-feedback
  { transmission-id: uint }
  {
    recipient-rating: uint,
    recipient-feedback: (string-ascii 200),
    wisdom-impact-score: uint
  }
)

(define-data-var next-transmission-id uint u1)

;; Schedule wisdom transmission
(define-public (schedule-transmission (legacy-id uint)
                                    (recipient-id principal)
                                    (transmission-method (string-ascii 50))
                                    (scheduled-date uint)
                                    (notes (string-ascii 300)))
  (let ((transmission-id (var-get next-transmission-id)))
    ;; Basic validation
    (asserts! (not (is-eq tx-sender recipient-id)) ERR_INVALID_RECIPIENT)
    (asserts! (> scheduled-date block-height) ERR_INVALID_RECIPIENT)

    ;; Create transmission record
    (map-set wisdom-transmissions
      { transmission-id: transmission-id }
      {
        legacy-id: legacy-id,
        transmitter-id: tx-sender,
        recipient-id: recipient-id,
        transmission-method: transmission-method,
        scheduled-date: scheduled-date,
        completion-date: none,
        status: STATUS_PENDING,
        notes: notes
      }
    )

    ;; Update recipient's transmission list
    (match (map-get? recipient-transmissions { recipient-id: recipient-id })
      existing-transmissions
      (map-set recipient-transmissions
        { recipient-id: recipient-id }
        { transmission-ids: (unwrap! (as-max-len? (append (get transmission-ids existing-transmissions) transmission-id) u100) ERR_INVALID_RECIPIENT) }
      )
      (map-set recipient-transmissions
        { recipient-id: recipient-id }
        { transmission-ids: (list transmission-id) }
      )
    )

    (var-set next-transmission-id (+ transmission-id u1))
    (ok transmission-id)
  )
)

;; Activate transmission
(define-public (activate-transmission (transmission-id uint))
  (match (map-get? wisdom-transmissions { transmission-id: transmission-id })
    transmission-data
    (begin
      (asserts! (is-eq tx-sender (get transmitter-id transmission-data)) ERR_UNAUTHORIZED)
      (asserts! (>= block-height (get scheduled-date transmission-data)) ERR_UNAUTHORIZED)
      (map-set wisdom-transmissions
        { transmission-id: transmission-id }
        (merge transmission-data { status: STATUS_ACTIVE })
      )
      (ok true)
    )
    ERR_TRANSMISSION_NOT_FOUND
  )
)

;; Complete transmission
(define-public (complete-transmission (transmission-id uint))
  (match (map-get? wisdom-transmissions { transmission-id: transmission-id })
    transmission-data
    (begin
      (asserts! (or (is-eq tx-sender (get transmitter-id transmission-data))
                    (is-eq tx-sender (get recipient-id transmission-data))) ERR_UNAUTHORIZED)
      (map-set wisdom-transmissions
        { transmission-id: transmission-id }
        (merge transmission-data {
          status: STATUS_COMPLETED,
          completion-date: (some block-height)
        })
      )
      (ok true)
    )
    ERR_TRANSMISSION_NOT_FOUND
  )
)

;; Submit transmission feedback
(define-public (submit-feedback (transmission-id uint)
                               (rating uint)
                               (feedback (string-ascii 200))
                               (impact-score uint))
  (match (map-get? wisdom-transmissions { transmission-id: transmission-id })
    transmission-data
    (begin
      (asserts! (is-eq tx-sender (get recipient-id transmission-data)) ERR_UNAUTHORIZED)
      (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RECIPIENT)
      (asserts! (and (>= impact-score u1) (<= impact-score u10)) ERR_INVALID_RECIPIENT)
      (map-set transmission-feedback
        { transmission-id: transmission-id }
        {
          recipient-rating: rating,
          recipient-feedback: feedback,
          wisdom-impact-score: impact-score
        }
      )
      (ok true)
    )
    ERR_TRANSMISSION_NOT_FOUND
  )
)

;; Get transmission details
(define-read-only (get-transmission (transmission-id uint))
  (map-get? wisdom-transmissions { transmission-id: transmission-id })
)

;; Get recipient transmissions
(define-read-only (get-recipient-transmissions (recipient-id principal))
  (map-get? recipient-transmissions { recipient-id: recipient-id })
)

;; Get transmission feedback
(define-read-only (get-transmission-feedback (transmission-id uint))
  (map-get? transmission-feedback { transmission-id: transmission-id })
)
