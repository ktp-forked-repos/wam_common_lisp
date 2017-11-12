;;;; -*- emacs-lisp -*-
;;;
;;; Copyright (C) 2003 Lars Brinkhoff.
;;; This file implements operators in chapter 18, Hash Tables.

(IN-PACKAGE "EMACS-CL")

(if (eq (type-of (make-hash-table)) 'hash-table)
    (progn
      (cl:defun MAKE-HASH-TABLE (&KEY TEST SIZE REHASH-SIZE REHASH-THRESHOLD)
	(make-hash-table :test TEST :size SIZE))

      (defmacro htab (hash)
	hash)

      (defun HASH-TABLE-P (object)
	(hash-table-p object))

      (defun HASH-TABLE-TEST (hash)
	;; TODO
	'EQ))

    ;; If there isn't a real hash-table type, make one using defstruct.
    (progn
      (DEFSTRUCT (HASH-TABLE (:copier nil) (:constructor mkhash (TABLE TEST)))
        TABLE TEST)

      (defun* MAKE-HASH-TABLE (&key TEST SIZE REHASH-SIZE REHASH-THRESHOLD)
	(mkhash (make-hash-table :test TEST :size SIZE) TEST))

      (defun htab (hash)
	(HASH-TABLE-TABLE hash))))

(defun HASH-TABLE-COUNT (hash)
  (hash-table-count (htab hash)))

(defun HASH-TABLE-REHASH-SIZE (hash)
  ;; TODO
  0)

(defun HASH-TABLE-REHASH-THRESHOLD (hash)
  ;; TODO
  0)

(defun HASH-TABLE-SIZE (hash)
  ;; TODO
  0)

(defun GETHASH (key hash &optional default)
  (let ((object (gethash key (htab hash) not-found)))
    (if (eq object not-found)
	(cl:values default nil)
	(cl:values object T))))

(unless (fboundp 'puthash)
  (defun puthash (key value table)
    (setf (gethash key table) value)))

(DEFINE-SETF-EXPANDER GETHASH (key hash &optional default)
  (with-gensyms (keytemp hashtemp val)
    (cl:values (list keytemp hashtemp)
	    (list key hash)
	    (list val)
	    `(puthash ,keytemp ,val ,hashtemp)
	    `(GETHASH ,keytemp ,hashtemp))))

(defun REMHASH (key hash)
  (remhash key (htab hash)))

(defun MAPHASH (fn hash)
  (maphash fn (htab hash))
  nil)

(defun hashlist (hash)
  (let ((list nil))
    (maphash (lambda (k v) (push (cons k v) list)) hash)
    list))

(cl:defmacro WITH-HASH-TABLE-ITERATOR ((name hash) &body body)
  (with-gensyms (list)
    `(LET ((,list (hashlist ,hash)))
       (MACROLET ((,name ()
		    (QUOTE (IF (NULL ,list) (cl:values nil nil nil)
			       (LET ((cons (POP ,list)))
				 (cl:values T (CAR cons) (CDR cons)))))))
	 ,@body))))

(defun CLRHASH (hash)
  (clrhash (htab hash))
  hash)

;;; TODO: SXHASH