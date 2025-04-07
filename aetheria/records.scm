(define-module (aetheria records)
  #:use-module ((srfi srfi-1) #:select (fold))
  #:use-module ((guix records) #:select (define-record-type*))
  #:export (define-foldable-record-type))

(define-syntax define-foldable-record-type
  (lambda (syn . rest)
    (define (process-properties err properties processed fold-variant has-default)
      (syntax-case properties (fold conflict list custom default)
        (((fold _) rest ...) (and fold-variant)
         (err "multiple duplicate fold variants"))

        ;; list/conflict
        (((fold conflict) rest ...) (not has-default)
         (process-properties err #'(rest ...) (cons #'(default *unspecified*) processed)
                             'conflict #f))
        (((fold list) rest ...) (not has-default)
         (process-properties err #'(rest ...) (cons #'(default '()) processed)
                             'list #f))
        (((default value) rest ...) (member fold-variant '(conflict list))
         (err "cannot set default value on ~a variant" fold-variant))
        (((default value) rest ...)
         (process-properties err #'(rest ...) (cons #'(default value) processed)
                             fold-variant #t))

        ;; custom fold, remember to validate
        (((fold custom proc-unchecked) rest ...)
         (process-properties err #'(rest ...) processed
                             #'proc-unchecked has-default))

        (((fold _ ...) rest ...)
         (err "invalid fold variant"))

        (((k v) rest ...)
         (begin
           (process-properties err #'(rest ...) (cons #'(k v) processed)
                               fold-variant has-default)))
        (() (not fold-variant)
         (err "missing (fold <variant>)"))
        (()
         (values fold-variant processed))))
    (define (process-fields err fields fold-parts processed)
      (syntax-case fields ()
        (((field get properties ...) rest ...)
         (call-with-values (lambda () (process-properties err #'(properties ...) #'() #f #f))
           (lambda (variant cleaned-properties)
             (process-fields err #'(rest ...)
                             (cons (lambda (record acc x)
                                     (make-fold-part record acc x #'field #'get variant))
                                   fold-parts)
                             (cons #`(field get #,@cleaned-properties) processed)))))
        (()
         (values fold-parts processed))))
    (define (make-fold-part record acc x field get variant)
      (syntax-case (list record acc x field get variant) (conflict list)
        ((record acc x field get list)
         #'(field (append (get acc) (get x))))
        ((record acc x field get conflict)
         (let* ((msg (format #f "multiple conflicting definitions for ~a"
                             (syntax->datum #'field)))
                (conflict-case #`(and (not (unspecified? (get acc)))
                                      (not (equal? (get x) (get acc))))))
           #`(field (cond
                     (#,conflict-case (error 'record #,msg acc x))
                     ((not (unspecified? (get acc))) (get acc))
                     ((not (unspecified? (get x))) (get x))))))
        ((record acc x field get custom)
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
                                    (syntactic-ctor #,@(map (lambda (fn) (fn #'type #'acc #'x)) fold-parts))))
                            default
                            lst)))))))))
