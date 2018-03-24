;;; fill-function-arguments.el --- Convert function arguments to/from single line -*- lexical-binding: t; -*-

;; Copyright (C) 2015 Free Software Foundation, Inc.

;; Author: David Shepherd <davidshepherd7@gmail.com>
;; Version: 0.4
;; Package-Requires: ((emacs "24.5"))
;; Keywords: convenience
;; URL: https://github.com/davidshepherd7/fill-function-arguments

;;; Commentary:

;; Add/remove line breaks between function arguments and similar constructs
;;
;; Put point inside the brackets and call `fill-function-arguments-dwim` to convert
;;
;; frobinate_foos(bar, baz, a_long_argument_just_for_fun, get_value(x, y))
;;
;; to
;;
;; frobinate_foos(
;;                bar,
;;                baz,
;;                a_long_argument_just_for_fun,
;;                get_value(x, y)
;;                )
;;
;; and back.
;;
;; Also works with arrays (`[x, y, z]`) and dictionary literals (`{a: b, c: 1}`).
;;
;; If no function call is found `fill-function-arguments-dwim` will call `fill-paragraph`,
;; so you can replace an existing `fill-paragraph` keybinding with it.
;;


;;; Code:


(defcustom fill-function-arguments-fall-through-to-fill-paragraph
  t
  "If true dwim will fill paragraphs when in comments or strings."
  :group 'fill-function-arguments)

(defcustom fill-function-arguments-first-argument-same-line
  nil
  "If true keep the first argument on the same line as the opening paren (e.g. as needed by xml tags)."
  :group 'fill-function-arguments
  )

(defcustom fill-function-arguments-second-argument-same-line
  nil
  "If true keep the second argument on the same line as the first argument.

e.g. as used in lisps like `(foo x
                                 bar)'"
  :group 'fill-function-arguments
  )

(defcustom fill-function-arguments-last-argument-same-line
  nil
  "If true keep the last argument on the same line as the closing paren (e.g. as done in Lisp)."
  :group 'fill-function-arguments
  )

(defcustom fill-function-arguments-argument-separator
  ","
  "Character separating arguments."
  :group 'fill-function-arguments
  )



;;; Helpers

(defun fill-function-arguments--in-comment-p ()
  "Check if we are inside a comment."
  (nth 4 (syntax-ppss)))

(defun fill-function-arguments--in-docs-p ()
  "Check if we are inside a string or comment."
  (nth 8 (syntax-ppss)))

(defun fill-function-arguments--opening-paren-location ()
  "Find the location of the current opening parenthesis."
  (nth 1 (syntax-ppss)))

(defun fill-function-arguments--enclosing-paren ()
  "Return the opening parenthesis of the enclosing parens, or nil if not inside any parens."
  (let ((ppss (syntax-ppss)))
    (when (nth 1 ppss)
      (char-after (nth 1 ppss)))))

(defun fill-function-arguments--paren-locations ()
  "Get a pair containing the enclosing parens."
  (let ((start (fill-function-arguments--opening-paren-location)))
    (when start
      (cons start
            ;; matching paren
            (save-excursion
              (goto-char start)
              (forward-sexp)
              (point))))))

(defun fill-function-arguments--narrow-to-brackets ()
  "Narrow to region inside current brackets."
  (interactive)
  (let ((l (fill-function-arguments--paren-locations)))
    (when l
      (narrow-to-region (car l) (cdr l)))
    t))

(defun fill-function-arguments--single-line-p()
  "Is the current function call on a single line?"
  (equal (line-number-at-pos (point-max)) 1))

(defun fill-function-arguments--do-argument-fill-p ()
  "Should we call fill-paragraph?"
  (and fill-function-arguments-fall-through-to-fill-paragraph
       (or (fill-function-arguments--in-comment-p)
           (fill-function-arguments--in-docs-p)
           (and (derived-mode-p 'sgml-mode)
                (not (equal (fill-function-arguments--enclosing-paren) ?<))))))



;;; Main functions

(defun fill-function-arguments-to-single-line ()
  "Convert current bracketed list to a single line."
  (interactive)
  (save-excursion
    (save-restriction
      (fill-function-arguments--narrow-to-brackets)
      (while (not (fill-function-arguments--single-line-p))
        (goto-char (point-max))
        (delete-indentation)))))

(defun fill-function-arguments-to-multi-line ()
  "Convert current bracketed list to one line per argument."
  (interactive)
  (let ((initial-opening-paren (fill-function-arguments--opening-paren-location)))
    (save-excursion
      (save-restriction
        (fill-function-arguments--narrow-to-brackets)
        (goto-char (point-min))

        ;; newline after opening paren
        (forward-char)
        (when (not fill-function-arguments-first-argument-same-line)
          (insert "\n"))

        (when fill-function-arguments-second-argument-same-line
          ;; Just move point after the second argument before we start
          (search-forward fill-function-arguments-argument-separator nil t))

        ;; Split the arguments
        (while (search-forward fill-function-arguments-argument-separator nil t)
          ;; We have to save the match data here because the functions below
          ;; could (and sometimes do) modify it.
          (let ((saved-match-data (match-data)))
            (when (save-excursion (and (not (fill-function-arguments--in-docs-p))
                                       (equal (fill-function-arguments--opening-paren-location) initial-opening-paren)))
              (set-match-data saved-match-data)
              (replace-match (concat fill-function-arguments-argument-separator "\n")))))

        ;; Newline before closing paren
        (when (not fill-function-arguments-last-argument-same-line)
          (goto-char (point-max))
          (backward-char)
          (insert "\n"))))))

(defun fill-function-arguments-dwim ()
  "Fill the thing at point in a context-sensitive way.

If point is a string or comment and
`fill-function-arguments-fall-through-to-fill-paragraph' is
enabled, then just run `fill-paragragh'.

Otherwise if point is inside a bracketed list (e.g. a function
call, an array declaration, etc.) then if the list is currently
on a single line call `fill-function-arguments-to-multi-line',
otherwise call `fill-function-arguments-to-single-line'."
  (interactive)
  (save-restriction
    (fill-function-arguments--narrow-to-brackets)
    (cond
     ((fill-function-arguments--do-argument-fill-p) (fill-paragraph))
     ((fill-function-arguments--single-line-p) (fill-function-arguments-to-multi-line))
     (t (fill-function-arguments-to-single-line)))))



(provide 'fill-function-arguments)

;;; fill-function-arguments.el ends here
