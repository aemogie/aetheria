(define-module (aetheria records)
  #:use-module ((srfi srfi-1) #:select (fold))
  #:use-module ((guix records) #:select (define-record-type*))
  #:export (define-foldable-record-type))

(define-syntax define-foldable-record-type
  (lambda (syn)
    (define (process-properties err properties processed fold-variant default-found?)
      (syntax-case properties (fold conflict list custom default)
        ((rest ... (fold _)) (and fold-variant)
         (err "multiple duplicate fold variants"))

        ;; default handling. should be disallowed on conflict/list variants
        ((rest ... (default value)) (member fold-variant '(conflict list))
         (err "cannot set default value on ~a variant" fold-variant))
        ((rest ... (fold conflict)) default-found?
         (err "cannot set default value on coflict variant"))
        ((rest ... (fold list)) default-found?
         (err "cannot set default value on list variant"))
        ((rest ... (default default-found?))
         (process-properties err #'(rest ...) (cons #'(default default-found?) processed)
                             fold-variant #'default-found?))

        ;; conflict/list
        ((rest ... (fold conflict))
         (process-properties err #'(rest ...) (cons #'(default *unspecified*) processed)
                             'conflict (datum->syntax syn #'*unspecified*)))
        ((rest ... (fold list))
         (process-properties err #'(rest ...) (cons #'(default '()) processed)
                             'list (datum->syntax syn #''())))

        ;; custom fold, remember to validate
        ((rest ... (fold custom proc-unchecked))
         (process-properties err #'(rest ...) processed
                             #'proc-unchecked default-found?))

        ((rest ... (fold _ ...))
         (err "invalid fold variant"))

        ((rest ... next)
         (begin
           (process-properties err #'(rest ...) (cons #'next processed)
                               fold-variant default-found?)))
        (() (not fold-variant)
         (err "missing (fold <variant>)"))
        (() (not default-found?)
         (err "missing (default <value>)"))
        (()
         (values fold-variant processed))))
    (define (process-fields err fields fold-parts processed)
      (syntax-case fields ()
        ((rest ... (field get properties ...))
         (call-with-values (lambda () (process-properties err #'(properties ...) #'() #f #f))
           (lambda (variant cleaned-properties)
             (process-fields err #'(rest ...)
                             (cons (lambda (record x acc)
                                     (make-fold-part record x acc #'field #'get variant))
                                   fold-parts)
                             (cons #`(field get #,@cleaned-properties) processed)))))
        (()
         (values fold-parts processed))))
    (define (make-fold-part record x acc field get variant)
      (syntax-case (list record x acc field get variant) (conflict list)
        ((record x acc field get list)
         #'(field (append (get acc) (get x))))
        ((record x acc field get conflict)
         (let* ((msg (format #f "multiple conflicting definitions for ~a"
                             (syntax->datum #'field)))
                (conflict-case #`(and (not (unspecified? (get acc)))
                                      (not (equal? (get x) (get acc))))))
           #`(field (cond
                     (#,conflict-case (error 'record #,msg acc x))
                     ((not (unspecified? (get acc))) (get acc))
                     ((not (unspecified? (get x))) (get x))))))
        ((record x acc field get custom)
         #'(field (let* ((custom* custom)
                         (arity (procedure-minimum-arity custom*)))
                    (unless (procedure? custom*)
                      (error 'record "custom fold wasn't a valid procedure"))
                    (unless (<= (car arity) 2 (+ (car arity) (cadr arity)))
                      (error 'record "custom fold has invalid arity"))
                    (custom* (get x) (get acc)))))))
    (syntax-case syn ()
      ((me type syntactic-ctor ctor pred fold-proc
           (field get properties ...) ...)
       #'(me type syntactic-ctor ctor pred fold-proc
             this-record
             (field get properties ...) ...))
      ((me type syntactic-ctor ctor pred fold-proc
           this-identifier
           (field get properties ...) ...)
       (call-with-values
           (lambda ()
             (define (err fmt . args)
               (syntax-violation (syntax->datum #'me) (apply format #f fmt args) syn))
             (process-fields err #'((field get properties ...) ...) '() #'()))
         (lambda (fold-parts fields)
           #`(begin
               (define-record-type* type syntactic-ctor ctor pred
                 this-identifier
                 #,@fields)
               (define (fold-proc lst default)
                 (fold #,(with-syntax
                             ((x (datum->syntax #'fold-proc 'x))
                              (acc (datum->syntax #'fold-proc 'acc)))
                           #`(lambda (x acc)
                               (syntactic-ctor #,@(map (lambda (fn) (fn #'type #'x #'acc))
                                                       fold-parts))))
                       default
                       lst)))))))))
