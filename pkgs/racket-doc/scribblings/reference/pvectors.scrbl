#lang scribble/doc
@(require "mz.rkt"
          (for-label racket/pvector
                     (submod racket/pvector unsafe)
                     racket/match
                     racket/place
                     racket/stream))

@(define pvector-eval (make-base-eval))
@(pvector-eval '(require racket/pvector
                         racket/match
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
Using @racket[stream->list], @racket[stream-length],
@racket[stream-ref], @racket[stream-tail], or @racket[stream-take] on
a pvector stream produces results consistent with the corresponding
pvector conversion, length, reference, and slicing operations. Appending
only pvector streams with @racket[stream-append] produces a pvector, and
using @racket[stream-add-between] on a pvector produces a pvector.
Using @racket[stream-map] with @racket[values] or @racket[void] on a
pvector produces a pvector. Using @racket[stream-filter] with
@racket[values] or @racket[void] on a pvector produces a pvector.
Traversal operations such as @racket[stream-for-each],
@racket[stream-fold], @racket[stream-count], @racket[stream-andmap],
and @racket[stream-ormap] visit pvector elements in order.
Pvectors compare with @racket[equal?] element by element. In the BC
runtime-native implementation, pvectors print as an unreadable summary
such as @racketresultfont{#<pvector:3>} and are not serializable in the
first stage of the native runtime backend. Pvectors are also not
accepted by @racket[place-message-allowed?] in this first stage. Compatibility
backends may print pvectors as @racket[(pvector elem ...)] and may
support serialization.

@note-lib[racket/pvector #:use-sources (racket/pvector)]

@examples[
#:eval pvector-eval
(define items (pvector "a" "b" "c"))
(for/list ([v items]) v)
(stream-first items)
(stream->list (stream-rest items))
(equal? (pvector 1 2 3) (list->pvector '(1 2 3)))
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

@defproc[(pvector-map [pv pvector?] [proc (any/c . -> . any/c)]) pvector?]{

Produces a pvector by applying @racket[proc] to each element of
@racket[pv] and gathering the results into a new pvector. For a
constant-time @racket[proc], this operation takes @math{O(N)} time.

@examples[
#:eval pvector-eval
(pvector-map (pvector 1 2 3) add1)
]}

@defproc[(pvector-for-each [pv pvector?] [proc (any/c . -> . any)])
         void?]{

Applies @racket[proc] to each element of @racket[pv], ignoring the
results. For a constant-time @racket[proc], this operation takes
@math{O(N)} time.

@examples[
#:eval pvector-eval
(define nums (pvector 1 2 3))
(define total 0)
(pvector-for-each nums (lambda (v) (set! total (+ total v))))
total
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

@defproc[(make-pvector-literal-pool) pvector-literal-pool?]{

Returns a mutable output pool for pvector literal data. Reusing the
same pool across calls to @racket[pvector->literal-datum] or
@racket[pvectors->literal-datum] allows shared runtime tree nodes to
receive a single id in the emitted definition table.}

@defproc[(pvector-literal-pool? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[v] is a pvector literal output pool,
@racket[#f] otherwise.}

@defproc[(pvector->literal-datum [pv pvector?]
                                  [pool pvector-literal-pool?
                                        (make-pvector-literal-pool)]
                                  [#:mode mode (or/c 'raw 'expanded) 'raw])
         any/c]{

Returns a datum suitable for printing after @racketresultfont{#pvector}.
When @racket[mode] is @racket['expanded], the result has the shape:

@racketblock[
(list (list elem ...) #f)
]

When @racket[mode] is @racket['raw] and native literal support is
available, the result is a structure-preserving datum with the shape:

@racketblock[
(list root-id-or-Empty
      (list (list id val) ...))
]

The @racket[root-id-or-Empty] value is the id of the root structure
definition, or @racket['Empty] for an empty pvector; it is not the
pvector length. The ids in the definition table are dense, ascending,
and each definition refers only to earlier ids. The @racket[val]
variants are:

@racketblock[
Empty
(Single/val v)
(Single node-id)
(Digit/val size v ...)
(Digit size node-id ...)
(Node/val size v ...)
(Node size node-id ...)
(Deep/val size left-digit-id right-digit-id inner-id-or-Empty)
(Deep size left-digit-id right-digit-id inner-id-or-Empty)
]

The @racket[/val] variants contain pvector element values directly.
The other variants contain ids for previously emitted structure
definitions. When @racket[mode] is @racket['raw] but native literal
support is not available, the result uses the expanded shape.
}

@defproc[(pvectors->literal-datum [pvs sequence?]
                                   [pool pvector-literal-pool?
                                         (make-pvector-literal-pool)]
                                   [#:mode mode (or/c 'raw 'expanded) 'raw])
         any/c]{

Like @racket[pvector->literal-datum], but emits roots for all pvectors
in @racket[pvs] using the same @racket[pool]. On the native structural
path, the result has the shape @racket[(list roots defs)].
The shared definition table can preserve sharing among all pvectors in
@racket[pvs]. The result is a group datum for output helpers; it is not
a single @racketresultfont{#pvector} reader datum.}

@defproc[(literal-datum->pvector [datum any/c]) pvector?]{

Converts a datum in either single-pvector literal shape accepted by the
@racketresultfont{#pvector} reader into a pvector. The expanded shape is
@racket[(list elems #f)]. The raw shape is @racket[(list root defs)].}

@defproc[(write-pvector-literal [pv pvector?]
                                [out output-port? (current-output-port)]
                                [pool pvector-literal-pool?
                                      (make-pvector-literal-pool)]
                                [#:mode mode (or/c 'raw 'expanded) 'raw])
         void?]{

Writes @racketresultfont{#pvector} followed by the datum produced by
@racket[pvector->literal-datum]. This function is an explicit literal
output helper. The Racket reader accepts @racketresultfont{#pvector}
input in the expanded form @racketresultfont{#pvector((elem ...) #f)}
and in the raw form
@racketresultfont{#pvector(root-id-or-Empty defs)}.}

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
@defform/subs[(for/pvector maybe-length (for-clause ...) body-or-break ... body)
              ([maybe-length (code:line)
                             (code:line #:length length-expr)
                             (code:line #:length length-expr #:fill fill-expr)])
              #:contracts ([length-expr exact-nonnegative-integer?])]
@defform/subs[(for*/pvector maybe-length (for-clause ...) body-or-break ... body)
              ([maybe-length (code:line)
                             (code:line #:length length-expr)
                             (code:line #:length length-expr #:fill fill-expr)])
              #:contracts ([length-expr exact-nonnegative-integer?])]
)]{

Like @racket[for/vector] and @racket[for*/vector], but produces a
@tech{pvector}. If @racket[#:length] is specified, the result of
@racket[length-expr] determines the length of the result pvector, and
iteration stops when that many elements have been produced. If fewer
elements are produced, the remaining elements are initialized to
@racket[fill-expr], which defaults to @racket[0].

@examples[
#:eval pvector-eval
(for/pvector ([i (in-range 5)])
  (* i i))
(for/pvector #:length 4 #:fill 'done ([i (in-range 2)])
  i)
(for*/pvector ([i (in-range 3)]
               [j (in-range 2)])
  (list i j))
(for*/pvector #:length 4 ([i (in-range 3)]
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
@defproc[(unsafe-pvector->list [pv pvector?]) list?]
@defproc[(unsafe-pvector->vector [pv pvector?]) vector?]
)]{

Unchecked variants of @racket[pvector->list] and
@racket[pvector->vector].}

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
