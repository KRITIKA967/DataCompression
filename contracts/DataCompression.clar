;; Data Compression Contract
;; Build efficient data storage and compression utilities

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-data (err u101))
(define-constant err-data-not-found (err u102))
(define-constant err-unauthorized (err u103))

;; Data variables
(define-data-var data-count uint u0)
(define-data-var total-storage uint u0)

;; Storage maps
(define-map compressed-data uint {
  owner: principal,
  original-size: uint,
  compressed-size: uint,
  data-hash: (buff 32),
  timestamp: uint,
  metadata: (string-ascii 100)
})

(define-map data-storage uint (buff 2048))
(define-map user-data-count principal uint)

;; Function 1: Store compressed data
(define-public (store-compressed-data (data (buff 2048)) (original-size uint) (metadata (string-ascii 100)))
  (begin
    (asserts! (> original-size u0) err-invalid-data)
    (asserts! (> (len data) u0) err-invalid-data)
    (asserts! (> (len metadata) u0) err-invalid-data)
    
    (let ((data-id (+ (var-get data-count) u1))
          (compressed-size (len data))
          (data-hash (sha256 data)))
      
      ;; Store the actual data
      (map-set data-storage data-id data)
      
      ;; Store metadata information
      (map-set compressed-data data-id {
        owner: tx-sender,
        original-size: original-size,
        compressed-size: compressed-size,
        data-hash: data-hash,
        timestamp: stacks-block-height,
        metadata: metadata
      })
      
      ;; Update global counters
      (var-set data-count data-id)
      (var-set total-storage (+ (var-get total-storage) compressed-size))
      
      ;; Update user file count
      (map-set user-data-count tx-sender 
               (+ (default-to u0 (map-get? user-data-count tx-sender)) u1))
      
      (ok data-id))))

;; Function 2: Retrieve compressed data
(define-public (retrieve-compressed-data (data-id uint))
  (begin
    (asserts! (> data-id u0) err-invalid-data)
    (asserts! (<= data-id (var-get data-count)) err-data-not-found)
    
    (let ((data-info (unwrap! (map-get? compressed-data data-id) err-data-not-found))
          (stored-data (unwrap! (map-get? data-storage data-id) err-data-not-found)))
      
      ;; Check authorization
      (asserts! (or (is-eq tx-sender (get owner data-info)) 
                   (is-eq tx-sender contract-owner)) err-unauthorized)
      
      ;; Return complete data package
      (ok {
        data-id: data-id,
        data: stored-data,
        original-size: (get original-size data-info),
        compressed-size: (get compressed-size data-info),
        data-hash: (get data-hash data-info),
        timestamp: (get timestamp data-info),
        metadata: (get metadata data-info),
        owner: (get owner data-info)
      }))))

;; Read-only helper functions
(define-read-only (get-data-info (data-id uint))
  (map-get? compressed-data data-id))

(define-read-only (get-user-data-count (user principal))
  (default-to u0 (map-get? user-data-count user)))

(define-read-only (get-total-storage)
  (var-get total-storage))

(define-read-only (get-data-count)
  (var-get data-count))

(define-read-only (get-compression-stats)
  (ok {
    total-files: (var-get data-count),
    total-storage-bytes: (var-get total-storage)
  }))