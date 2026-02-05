(define-constant ERR_UNAUTHORIZED (err u3000))
(define-constant ERR_INVALID_INPUT (err u3001))
(define-constant ERR_NOT_FOUND (err u3002))
(define-constant ERR_INSUFFICIENT_BALANCE (err u3003))

(define-map storage { key: (string-ascii 50) } { value: uint })
(define-map user-balances principal uint)
(define-map user-rewards principal uint)
(define-map staking-positions principal { amount: uint, timestamp: uint })
(define-data-var total-supply uint u0)
(define-data-var total-staked uint u0)
(define-data-var contract-name (string-ascii 50) "Implementation V2")
(define-data-var reward-rate uint u5)

(define-public (execute (function-name (string-ascii 50)) (args (list 10 (buff 32))))
  (if (is-eq function-name "set-value")
    (execute-set-value args)
    (if (is-eq function-name "increase-balance") 
      (execute-increase-balance args)
      (if (is-eq function-name "mint-tokens")
        (execute-mint-tokens args)
        (if (is-eq function-name "stake-tokens")
          (execute-stake-tokens args)
          (if (is-eq function-name "unstake-tokens")
            (execute-unstake-tokens args)
            (if (is-eq function-name "claim-rewards")
              (execute-claim-rewards args)
              (err u3001))))))))

(define-public (read-execute (function-name (string-ascii 50)) (args (list 10 (buff 32))))
  (if (is-eq function-name "get-value")
    (read-get-value args)
    (if (is-eq function-name "get-balance")
      (read-get-balance args)
      (if (is-eq function-name "get-total-supply")
        (read-get-total-supply)
        (if (is-eq function-name "get-rewards")
          (read-get-rewards args)
          (if (is-eq function-name "get-staking-info")
            (read-get-staking-info args)
            (err u3001)))))))

(define-private (execute-set-value (args (list 10 (buff 32))))
  (let ((key "default-key")
        (value u100))
    (begin
      (map-set storage { key: key } { value: value })
      (ok value))))

(define-private (execute-increase-balance (args (list 10 (buff 32))))
  (let ((current-balance (default-to u0 (map-get? user-balances tx-sender)))
        (increase-amount u50))
    (begin
      (map-set user-balances tx-sender (+ current-balance increase-amount))
      (ok (+ current-balance increase-amount)))))

(define-private (execute-mint-tokens (args (list 10 (buff 32))))
  (let ((mint-amount u1000)
        (current-total (var-get total-supply)))
    (begin
      (var-set total-supply (+ current-total mint-amount))
      (map-set user-balances tx-sender 
        (+ (default-to u0 (map-get? user-balances tx-sender)) mint-amount))
      (ok mint-amount))))

(define-private (execute-stake-tokens (args (list 10 (buff 32))))
  (let ((stake-amount u500)
        (current-balance (default-to u0 (map-get? user-balances tx-sender)))
        (current-staked (var-get total-staked)))
    (begin
      (asserts! (>= current-balance stake-amount) ERR_INSUFFICIENT_BALANCE)
      (map-set user-balances tx-sender (- current-balance stake-amount))
      (map-set staking-positions tx-sender 
        { amount: stake-amount, timestamp: stacks-block-height })
      (var-set total-staked (+ current-staked stake-amount))
      (ok stake-amount))))

(define-private (execute-unstake-tokens (args (list 10 (buff 32))))
  (match (map-get? staking-positions tx-sender)
    position
      (let ((stake-amount (get amount position))
            (current-balance (default-to u0 (map-get? user-balances tx-sender)))
            (current-staked (var-get total-staked)))
        (begin
          (map-delete staking-positions tx-sender)
          (map-set user-balances tx-sender (+ current-balance stake-amount))
          (var-set total-staked (- current-staked stake-amount))
          (ok stake-amount)))
    (err u3002)))

(define-private (execute-claim-rewards (args (list 10 (buff 32))))
  (let ((pending-rewards (calculate-rewards tx-sender))
        (current-rewards (default-to u0 (map-get? user-rewards tx-sender))))
    (begin
      (map-set user-rewards tx-sender u0)
      (map-set user-balances tx-sender 
        (+ (default-to u0 (map-get? user-balances tx-sender)) pending-rewards))
      (ok pending-rewards))))

(define-private (calculate-rewards (user principal))
  (match (map-get? staking-positions user)
    position
      (let ((stake-amount (get amount position))
            (stake-time (get timestamp position))
            (time-staked (- stacks-block-height stake-time))
            (reward-multiplier (var-get reward-rate)))
        (* (* stake-amount reward-multiplier) time-staked))
    u0))

(define-private (read-get-value (args (list 10 (buff 32))))
  (let ((key "default-key"))
    (ok (default-to u0 (get value (map-get? storage { key: key }))))))

(define-private (read-get-balance (args (list 10 (buff 32))))
  (ok (default-to u0 (map-get? user-balances tx-sender))))

(define-private (read-get-total-supply)
  (ok (var-get total-supply)))

(define-private (read-get-rewards (args (list 10 (buff 32))))
  (ok (+ (default-to u0 (map-get? user-rewards tx-sender)) 
         (calculate-rewards tx-sender))))

(define-private (read-get-staking-info (args (list 10 (buff 32))))
  (ok (var-get total-staked)))

(define-read-only (get-contract-info)
  {
    name: (var-get contract-name),
    version: u2,
    features: (list "storage" "balances" "minting" "staking" "rewards")
  })

(define-read-only (get-version-info)
  "This is Implementation Version 2 - Enhanced with staking and rewards system")
