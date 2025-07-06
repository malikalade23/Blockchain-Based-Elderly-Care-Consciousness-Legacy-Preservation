;; Family Connection Contract
;; Connects families with consciousness legacy preservation

(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_CONNECTION_NOT_FOUND (err u401))
(define-constant ERR_INVALID_RELATIONSHIP (err u402))
(define-constant ERR_CONNECTION_EXISTS (err u403))

;; Relationship types
(define-constant RELATIONSHIP_CHILD u1)
(define-constant RELATIONSHIP_GRANDCHILD u2)
(define-constant RELATIONSHIP_SIBLING u3)
(define-constant RELATIONSHIP_SPOUSE u4)
(define-constant RELATIONSHIP_FRIEND u5)
(define-constant RELATIONSHIP_CAREGIVER u6)

;; Data structures
(define-map family-connections
  { connection-id: uint }
  {
    elder-id: principal,
    family-member-id: principal,
    relationship-type: uint,
    connection-date: uint,
    access-level: uint,
    verified: bool,
    contact-frequency: uint
  }
)

(define-map elder-family-network
  { elder-id: principal }
  { connection-ids: (list 50 uint) }
)

(define-map family-member-connections
  { family-member-id: principal }
  { elder-connection-ids: (list 20 uint) }
)

(define-map connection-permissions
  { connection-id: uint }
  {
    can-view-legacies: bool,
    can-receive-transmissions: bool,
    can-add-memories: bool,
    can-invite-others: bool
  }
)

(define-data-var next-connection-id uint u1)

;; Create family connection
(define-public (create-family-connection (elder-id principal)
                                       (family-member-id principal)
                                       (relationship-type uint)
                                       (access-level uint))
  (let ((connection-id (var-get next-connection-id)))
    ;; Validate relationship type
    (asserts! (and (>= relationship-type u1) (<= relationship-type u6)) ERR_INVALID_RELATIONSHIP)
    (asserts! (not (is-eq elder-id family-member-id)) ERR_INVALID_RELATIONSHIP)

    ;; Create connection record
    (map-set family-connections
      { connection-id: connection-id }
      {
        elder-id: elder-id,
        family-member-id: family-member-id,
        relationship-type: relationship-type,
        connection-date: block-height,
        access-level: access-level,
        verified: false,
        contact-frequency: u0
      }
    )

    ;; Set default permissions based on relationship
    (map-set connection-permissions
      { connection-id: connection-id }
      (if (or (is-eq relationship-type RELATIONSHIP_CHILD)
              (is-eq relationship-type RELATIONSHIP_SPOUSE))
        {
          can-view-legacies: true,
          can-receive-transmissions: true,
          can-add-memories: true,
          can-invite-others: true
        }
        {
          can-view-legacies: true,
          can-receive-transmissions: true,
          can-add-memories: false,
          can-invite-others: false
        }
      )
    )

    ;; Update elder's family network
    (match (map-get? elder-family-network { elder-id: elder-id })
      existing-network
      (map-set elder-family-network
        { elder-id: elder-id }
        { connection-ids: (unwrap! (as-max-len? (append (get connection-ids existing-network) connection-id) u50) ERR_CONNECTION_EXISTS) }
      )
      (map-set elder-family-network
        { elder-id: elder-id }
        { connection-ids: (list connection-id) }
      )
    )

    ;; Update family member's connections
    (match (map-get? family-member-connections { family-member-id: family-member-id })
      existing-connections
      (map-set family-member-connections
        { family-member-id: family-member-id }
        { elder-connection-ids: (unwrap! (as-max-len? (append (get elder-connection-ids existing-connections) connection-id) u20) ERR_CONNECTION_EXISTS) }
      )
      (map-set family-member-connections
        { family-member-id: family-member-id }
        { elder-connection-ids: (list connection-id) }
      )
    )

    (var-set next-connection-id (+ connection-id u1))
    (ok connection-id)
  )
)

;; Verify family connection
(define-public (verify-connection (connection-id uint))
  (match (map-get? family-connections { connection-id: connection-id })
    connection-data
    (begin
      (asserts! (is-eq tx-sender (get elder-id connection-data)) ERR_UNAUTHORIZED)
      (map-set family-connections
        { connection-id: connection-id }
        (merge connection-data { verified: true })
      )
      (ok true)
    )
    ERR_CONNECTION_NOT_FOUND
  )
)

;; Update contact frequency
(define-public (update-contact-frequency (connection-id uint) (frequency uint))
  (match (map-get? family-connections { connection-id: connection-id })
    connection-data
    (begin
      (asserts! (or (is-eq tx-sender (get elder-id connection-data))
                    (is-eq tx-sender (get family-member-id connection-data))) ERR_UNAUTHORIZED)
      (map-set family-connections
        { connection-id: connection-id }
        (merge connection-data { contact-frequency: frequency })
      )
      (ok true)
    )
    ERR_CONNECTION_NOT_FOUND
  )
)

;; Update connection permissions
(define-public (update-permissions (connection-id uint)
                                 (can-view-legacies bool)
                                 (can-receive-transmissions bool)
                                 (can-add-memories bool)
                                 (can-invite-others bool))
  (match (map-get? family-connections { connection-id: connection-id })
    connection-data
    (begin
      (asserts! (is-eq tx-sender (get elder-id connection-data)) ERR_UNAUTHORIZED)
      (map-set connection-permissions
        { connection-id: connection-id }
        {
          can-view-legacies: can-view-legacies,
          can-receive-transmissions: can-receive-transmissions,
          can-add-memories: can-add-memories,
          can-invite-others: can-invite-others
        }
      )
      (ok true)
    )
    ERR_CONNECTION_NOT_FOUND
  )
)

;; Get family connection
(define-read-only (get-family-connection (connection-id uint))
  (map-get? family-connections { connection-id: connection-id })
)

;; Get elder's family network
(define-read-only (get-elder-family-network (elder-id principal))
  (map-get? elder-family-network { elder-id: elder-id })
)

;; Get family member connections
(define-read-only (get-family-member-connections (family-member-id principal))
  (map-get? family-member-connections { family-member-id: family-member-id })
)

;; Get connection permissions
(define-read-only (get-connection-permissions (connection-id uint))
  (map-get? connection-permissions { connection-id: connection-id })
)
