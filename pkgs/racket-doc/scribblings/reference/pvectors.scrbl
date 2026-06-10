#lang scribble/doc
@(require "mz.rkt"
          (for-label racket/pvector
                     (submod racket/pvector unsafe)
                     racket/match
                     racket/serialize
                     racket/stream))

@(define pvector-eval (make-base-eval))
@(pvector-eval '(require racket/pvector
                         racket/match
                         racket/serialize
                         racket/stream))

@title[#:tag "pvector"]{Pvectors}

A @deftech{pvector} is an immutable sequence of elements with efficient
indexed access, updates, concatenation, splitting, and operations near
both ends. Unlike a @tech{list}, a pvector supports indexed access
without traversing from the front. Unlike a @tech{vector}, an update or
an operation that adds or removes elements returns a new pvector while
the old pvector remains intact.

Unless otherwise specified, operations on a pvector of length
@math{N} take @math{O(log N)} time. Constructing a pvector from all of
its elements, converting all of its elements, or iterating through all
of its elements takes @math{O(N)} time. The representation is
persistent, so results may share storage with their inputs, but sharing
is not observable except through performance and memory use.

Pvectors can be used directly as single-valued @tech{sequences}. They
can also be used as @tech{streams}; using @racket[stream-rest] on a
non-empty pvector produces a pvector with the first element removed.
Pvectors compare with @racket[equal?] element by element, print as
@racket[(pvector elem ...)], and are serializable.

@note-lib-only[racket/pvector]

@examples[
#:eval pvector-eval
(define items (pvector "a" "b" "c"))
(for/list ([v items]) v)
(stream-first items)
(stream->list (stream-rest items))
(equal? (pvector 1 2 3) (list->pvector '(1 2 3)))
(deserialize (serialize items))
]

@section{Constructing Pvectors}

@defproc[(pvector? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[v] is a @tech{pvector}, @racket[#f]
otherwise.}

@deftogether[(
@defproc[(pvector-empty) pvector?]
@defproc[(pvector-empty? [v any/c]) boolean?]
)]{

The @racket[pvector-empty] function returns an empty pvector. The
@racket[pvector-empty?] predicate returns @racket[#t] when @racket[v]
is an empty pvector, and @racket[#f] otherwise.

Both operations take @math{O(1)} time.

@examples[
#:eval pvector-eval
(pvector-empty)
(pvector-empty? (pvector-empty))
(pvector-empty? null)
]}

@defproc[(pvector [v any/c] ...) pvector?]{

Returns a pvector containing the @racket[v]s in order. Constructing a
pvector of @math{N} elements takes @math{O(N)} time. The same
@racket[pvector] binding can be used as a @racket[match] pattern, as
described in @secref["pvector-pattern-matching"].

@examples[
#:eval pvector-eval
(pvector 1 "a" 'apple)
(pvector->list (pvector 1 2 3))
(pvector->list (apply pvector '(1 2 3)))
]}

@section[#:tag "pvector-pattern-matching"]{Pattern Matching}

@racketblock[(pvector elem-pat ...)]

As a @racket[match] pattern, matches a pvector whose elements match
the @racket[elem-pat]s in order. The element patterns are matched as
in a @racket[list] pattern, so forms such as @racket[...] and
@racket[..k] have their usual list-pattern meaning. Variables bound by
repetition are bound to lists. Use @racket[pvector*] when a
variable-length interval should be matched as a pvector instead.

The pattern first checks @racket[pvector?]. A non-pvector value does
not match, even if it is a list or vector with matching elements.

@examples[
#:eval pvector-eval
(match (pvector "a" "b" "c")
  [(pvector first second third)
   (list third second first)])
(match (pvector 1 2 3 4)
  [(pvector 1 xs ..2) xs])
(match '(1 2 3)
  [(pvector _ _ _) 'pvector]
  [_ 'not-a-pvector])
]

@defform[(pvector* segment ...)
         #:grammar
         ([segment elem-pat
                   (code:line #:span len-expr pvector-pat)
                   (code:line #:rest pvector-pat)])]{

As a @racket[match] pattern, matches a pvector by splitting it into an
append-like sequence of element and pvector segments. An
@racket[elem-pat] segment matches one element. A @racket[#:span]
segment matches the next @racket[len-expr] elements as a pvector
against @racket[pvector-pat], where @racket[len-expr] must produce an
exact nonnegative integer; otherwise, the pattern fails. A
@racket[#:rest] segment matches the one variable-length interval, if
any, as a pvector.

At most one @racket[#:rest] segment is allowed. If no variable-length
segment appears, then the matched pvector must have exactly the total
length implied by the fixed element and pvector segments. If a
variable-length segment appears, then it receives all remaining
elements after the fixed-length constraints are satisfied. The
@racket[#:span] and @racket[#:rest] keywords are reserved as
@racket[pvector*] segment markers; other patterns, including
@racket[(pvector elem-pat ...)] for a pvector-valued element, are
treated as single element patterns.

The dotted form @racket[(pvector* elem-pat ... . pvector-pat)] is a
shorthand for a fixed prefix of element patterns followed by a
variable-length pvector tail.

@examples[
#:eval pvector-eval
(define letters (pvector "a" "b" "c" "d" "e"))
(match letters
  [(pvector* "a" #:rest middle "e")
   (pvector->list middle)])
(match letters
  [(pvector* #:span 2 left "c" #:span 2 right)
   (list (pvector->list left) (pvector->list right))])
(match letters
  [(pvector* "a" "b" . tail)
   (pvector->list tail)])
(match (pvector (pvector "x" "y") "z")
  [(pvector* (pvector first second) "z")
   (list first second)])
]}

@defproc[(make-pvector [size exact-nonnegative-integer?] [v any/c #f])
         pvector?]{

Returns a pvector of length @racket[size], where every element is
@racket[v]. This operation takes @math{O(N)} time for a result of
length @math{N}.

@examples[
#:eval pvector-eval
(make-pvector 0 'pear)
(make-pvector 3 'pear)
]}

@deftogether[(
@defproc[(list->pvector [lst list?]) pvector?]
@defproc[(vector->pvector [vec vector?]) pvector?]
@defproc[(sequence->pvector [seq sequence?]) pvector?]
)]{

Returns a pvector whose elements are the elements of @racket[lst],
@racket[vec], or @racket[seq] in order. Each element of @racket[seq]
must be a single value. If @racket[seq] is infinite, then
@racket[sequence->pvector] does not terminate.

If @racket[seq] is already a pvector, @racket[sequence->pvector] may
return it directly. Each conversion takes @math{O(N)} time for
@math{N} elements.

@examples[
#:eval pvector-eval
(list->pvector '(1 2 3))
(vector->pvector #(1 2 3))
(sequence->pvector (in-range 5))
]}

@section{Accessing and Updating}

@defproc[(pvector-length [pv pvector?]) exact-nonnegative-integer?]{

Returns the number of elements in @racket[pv]. This operation takes
@math{O(1)} time.

@examples[
#:eval pvector-eval
(pvector-length (pvector 'a 'b 'c))
]}

@defproc[(pvector-ref [pv pvector?] [pos exact-nonnegative-integer?])
         any/c]{

Returns the element of @racket[pv] at @racket[pos]. The first element
is at position @racket[0], and the last position is one less than
@racket[(pvector-length pv)]. This operation takes @math{O(log N)}
time.

@examples[
#:eval pvector-eval
(define letters (pvector "a" "b" "c"))
(pvector-ref letters 0)
(pvector-ref letters 2)
(eval:error (pvector-ref letters 3))
]}

@defproc[(pvector-set [pv pvector?]
                      [pos exact-nonnegative-integer?]
                      [v any/c])
         pvector?]{

Returns a pvector like @racket[pv], but with @racket[v] at
@racket[pos]. The original pvector is unchanged. This operation takes
@math{O(log N)} time.

@examples[
#:eval pvector-eval
(define letters (pvector "a" "b" "c"))
(pvector-set letters 1 "B")
letters
]}

@deftogether[(
@defproc[(pvector-first [pv pvector?]) any/c]
@defproc[(pvector-last [pv pvector?]) any/c]
)]{

Returns the first or last element of @racket[pv]. The pvector must be
non-empty.

@examples[
#:eval pvector-eval
(define letters (pvector "a" "b" "c"))
(pvector-first letters)
(pvector-last letters)
(eval:error (pvector-first (pvector-empty)))
]}

@section{Adding, Removing, and Combining}

@deftogether[(
@defproc[(pvector-cons-left [pv pvector?] [v any/c]) pvector?]
@defproc[(pvector-cons-right [pv pvector?] [v any/c]) pvector?]
)]{

Returns a pvector like @racket[pv], but with @racket[v] added at the
left or right end. The original pvector is unchanged.

@examples[
#:eval pvector-eval
(pvector-cons-left (pvector "b" "c") "a")
(pvector-cons-right (pvector "a" "b") "c")
]}

@deftogether[(
@defproc[(pvector-pop-left [pv pvector?]) (values any/c pvector?)]
@defproc[(pvector-pop-right [pv pvector?]) (values any/c pvector?)]
)]{

Returns two values: the removed element and the remaining pvector after
removing from the left or right end. The pvector must be non-empty.

@examples[
#:eval pvector-eval
(call-with-values
 (lambda () (pvector-pop-left (pvector "a" "b" "c")))
 list)
(call-with-values
 (lambda () (pvector-pop-right (pvector "a" "b" "c")))
 list)
]}

@defproc[(pvector-append [pv pvector?] [other-pv pvector?]) pvector?]{

Returns a pvector containing the elements of @racket[pv] followed by
the elements of @racket[other-pv].

@examples[
#:eval pvector-eval
(pvector-append (pvector 1 2) (pvector 3 4))
]}

@defproc[(pvector-insert [pv pvector?]
                         [pos exact-nonnegative-integer?]
                         [v any/c])
         pvector?]{

Returns a pvector like @racket[pv], but with @racket[v] inserted
before position @racket[pos]. The position may be @racket[0] to insert
at the front, or @racket[(pvector-length pv)] to insert at the end.

@examples[
#:eval pvector-eval
(pvector-insert (pvector "a" "c") 1 "b")
(pvector-insert (pvector "a" "b") 2 "c")
]}

@defproc[(pvector-delete [pv pvector?] [pos exact-nonnegative-integer?])
         (values pvector? any/c)]{

Returns two values: a pvector with the element at @racket[pos]
removed, and the removed element. The position must be less than
@racket[(pvector-length pv)].

@examples[
#:eval pvector-eval
(call-with-values
 (lambda () (pvector-delete (pvector "a" "b" "c") 1))
 list)
]}

@section{Taking, Dropping, and Splitting}

@deftogether[(
@defproc[(pvector-take [pv pvector?] [n exact-nonnegative-integer?]) pvector?]
@defproc[(pvector-drop [pv pvector?] [n exact-nonnegative-integer?]) pvector?]
@defproc[(pvector-take-right [pv pvector?] [n exact-nonnegative-integer?]) pvector?]
@defproc[(pvector-drop-right [pv pvector?] [n exact-nonnegative-integer?]) pvector?]
)]{

Returns a pvector with only the first @racket[n] elements, without the
first @racket[n] elements, with only the last @racket[n] elements, or
without the last @racket[n] elements, respectively. The @racket[n]
argument must be no greater than @racket[(pvector-length pv)].

@examples[
#:eval pvector-eval
(define letters (pvector "a" "b" "c" "d" "e"))
(pvector-take letters 3)
(pvector-drop letters 3)
(pvector-take-right letters 2)
(pvector-drop-right letters 2)
]}

@defproc[(pvector-subvector [pv pvector?]
                            [start exact-nonnegative-integer?]
                            [end exact-nonnegative-integer? (pvector-length pv)])
         pvector?]{

Returns a pvector containing the elements of @racket[pv] from
@racket[start] to @racket[end], not including @racket[end]. The
@racket[start] and @racket[end] arguments must be between @racket[0]
and @racket[(pvector-length pv)], inclusive, and @racket[start] must
not be greater than @racket[end].

@examples[
#:eval pvector-eval
(define letters (pvector "a" "b" "c" "d" "e"))
(pvector-subvector letters 1 4)
(pvector-subvector letters 2)
]}

@defproc[(pvector-split [pv pvector?] [pos exact-nonnegative-integer?])
         (values pvector? any/c pvector?)]{

Returns three values: the elements before @racket[pos], the element at
@racket[pos], and the elements after @racket[pos]. The position must
be less than @racket[(pvector-length pv)].

@examples[
#:eval pvector-eval
(call-with-values
 (lambda () (pvector-split (pvector "a" "b" "c" "d") 2))
 list)
]}

@defproc[(pvector-split-at [pv pvector?] [pos exact-nonnegative-integer?])
         (values pvector? pvector?)]{

Returns two values: a pvector containing the elements before
@racket[pos], and a pvector containing the elements starting at
@racket[pos]. The position may be any value from @racket[0] to
@racket[(pvector-length pv)], inclusive.

@examples[
#:eval pvector-eval
(call-with-values
 (lambda () (pvector-split-at (pvector "a" "b" "c" "d") 2))
 list)
]}

@section{Conversion and Iteration}

@deftogether[(
@defproc[(pvector->list [pv pvector?]) list?]
@defproc[(pvector->vector [pv pvector?]) vector?]
)]{

Returns a newly allocated list or mutable vector containing the
elements of @racket[pv] in order. Each operation takes @math{O(N)}
time.

@examples[
#:eval pvector-eval
(define letters (pvector "a" "b" "c"))
(pvector->list letters)
(pvector->vector letters)
]}

@deftogether[(
@defproc[(in-pvector [pv pvector?]) sequence?]
@defproc[(in-pvector-reverse [pv pvector?]) sequence?]
)]{

Returns a @tech{sequence} for the elements of @racket[pv] in forward
or reverse order. The pvector can also be used directly as a sequence,
but these functions make the intended traversal direction explicit.

@examples[
#:eval pvector-eval
(for/list ([v (in-pvector (pvector "a" "b" "c"))]) v)
(for/list ([v (in-pvector-reverse (pvector "a" "b" "c"))]) v)
]}

@deftogether[(
@defform[(for/pvector (for-clause ...) body-or-break ... body)]
@defform[(for*/pvector (for-clause ...) body-or-break ... body)]
)]{

Like @racket[for/list] and @racket[for*/list], but produces a
@tech{pvector}.

@examples[
#:eval pvector-eval
(for/pvector ([i (in-range 5)])
  (* i i))
(for*/pvector ([i (in-range 3)]
               [j (in-range 2)])
  (list i j))
]}

@section{Unsafe Pvector Operations}

@defmodule[(submod racket/pvector unsafe)]

The @racketmodname[(submod racket/pvector unsafe)] submodule provides
unchecked variants of pvector operations. They assume that arguments
satisfy the same constraints as the corresponding checked functions in
@racketmodname[racket/pvector]. In particular, pvector arguments must
be pvectors, index arguments must be exact nonnegative integers in
range, and operations that remove or inspect an end require a non-empty
pvector.

If these constraints are violated, behavior is unpredictable. Use the
unsafe operations only when the constraints are guaranteed by other
parts of the program and avoiding checks matters.

@deftogether[(
@defproc[(unsafe-pvector-length [pv pvector?]) exact-nonnegative-integer?]
@defproc[(unsafe-pvector-ref [pv pvector?] [pos exact-nonnegative-integer?]) any/c]
@defproc[(unsafe-pvector-set [pv pvector?] [pos exact-nonnegative-integer?] [v any/c]) pvector?]
@defproc[(unsafe-pvector-first [pv pvector?]) any/c]
@defproc[(unsafe-pvector-last [pv pvector?]) any/c]
)]{

Unchecked variants of @racket[pvector-length],
@racket[pvector-ref], @racket[pvector-set],
@racket[pvector-first], and @racket[pvector-last].}

@deftogether[(
@defproc[(unsafe-pvector-cons-left [pv pvector?] [v any/c]) pvector?]
@defproc[(unsafe-pvector-cons-right [pv pvector?] [v any/c]) pvector?]
@defproc[(unsafe-pvector-pop-left [pv pvector?]) (values any/c pvector?)]
@defproc[(unsafe-pvector-pop-right [pv pvector?]) (values any/c pvector?)]
@defproc[(unsafe-pvector-append [pv pvector?] [other-pv pvector?]) pvector?]
@defproc[(unsafe-pvector-insert [pv pvector?] [pos exact-nonnegative-integer?] [v any/c]) pvector?]
@defproc[(unsafe-pvector-delete [pv pvector?] [pos exact-nonnegative-integer?]) (values pvector? any/c)]
)]{

Unchecked variants of the corresponding adding, removing, and
combining operations.}

@deftogether[(
@defproc[(unsafe-pvector-take [pv pvector?] [n exact-nonnegative-integer?]) pvector?]
@defproc[(unsafe-pvector-drop [pv pvector?] [n exact-nonnegative-integer?]) pvector?]
@defproc[(unsafe-pvector-take-right [pv pvector?] [n exact-nonnegative-integer?]) pvector?]
@defproc[(unsafe-pvector-drop-right [pv pvector?] [n exact-nonnegative-integer?]) pvector?]
@defproc[(unsafe-pvector-subvector [pv pvector?]
                                   [start exact-nonnegative-integer?]
                                   [end exact-nonnegative-integer?])
         pvector?]
@defproc[(unsafe-pvector-split [pv pvector?] [pos exact-nonnegative-integer?])
         (values pvector? any/c pvector?)]
@defproc[(unsafe-pvector-split-at [pv pvector?] [pos exact-nonnegative-integer?])
         (values pvector? pvector?)]
)]{

Unchecked variants of the corresponding slicing and splitting
operations.}

@deftogether[(
@defproc[(unsafe-in-pvector [pv pvector?]) sequence?]
@defproc[(unsafe-in-pvector-reverse [pv pvector?]) sequence?]
)]{

Unchecked variants of @racket[in-pvector] and
@racket[in-pvector-reverse].}
