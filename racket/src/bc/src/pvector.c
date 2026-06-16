#include "schpriv.h"

static Scheme_Object *core_pvector_empty;
Scheme_Object *scheme_pvector_empty;

static Scheme_Object *core_pvector_p(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_empty_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_empty_p(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_length_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_shape_stats(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_vector_to_pvector(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_immutable_vector_to_pvector(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_fresh_vector_to_pvector(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_list_to_pvector(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_make_single_pvector(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_make_deep2_pvector(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_make_deep3_pvector(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_make_deep4_pvector(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_make_pvector(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_to_vector(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_to_list(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_ref_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_unsafe_pvector_length_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_unsafe_pvector_ref_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_unsafe_pvector_view_left_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_unsafe_pvector_view_right_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_cursor_start_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_cursor_next_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_set_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_cons_left_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_cons_right_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_pop_left_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_pop_right_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_append_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_map_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_for_each_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_split_at_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_split_at_right_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_split_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_insert_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_delete_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_take_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_drop_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_take_right_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_drop_right_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_copy_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_view_left(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_view_right(int argc, Scheme_Object *argv[]);
static int pvector_equal(Scheme_Object *left_obj, Scheme_Object *right_obj,
                         void *cycle_data);
static intptr_t pvector_hash1(Scheme_Object *pv_obj, intptr_t base,
                              void *cycle_data);
static intptr_t pvector_hash2(Scheme_Object *pv_obj, void *cycle_data);
static void pvector_print(Scheme_Object *pv_obj, int for_display,
                          Scheme_Print_Params *pp);

static Scheme_Object *pvector_from_small_fields(int count,
                                                Scheme_Object *a,
                                                Scheme_Object *b,
                                                Scheme_Object *c,
                                                Scheme_Object *d);
static Scheme_Object *pvector_append_unsafe(Scheme_Object *left_obj,
                                            Scheme_Object *right_obj);
static Scheme_Object *pvector_from_prefix_middle_digit_unsafe(Scheme_Object *prefix,
                                                              int prefix_len,
                                                              Scheme_Object *middle);
static Scheme_Object *pvector_from_middle_suffix_digit_unsafe(Scheme_Object *middle,
                                                              Scheme_Object *suffix,
                                                              int suffix_len);
static Scheme_Object *pvector_tree_child_to_pvector_unsafe(Scheme_Object *child);
static Scheme_Object *pvector_append_node_tree_unsafe(Scheme_Object *pv_obj,
                                                      Scheme_Object *node_obj);
static Scheme_Object *pvector_append_tree_child_unsafe(Scheme_Object *pv_obj,
                                                       Scheme_Object *child);
static Scheme_Object *pvector_append_pvector_part_unsafe(Scheme_Object *left_obj,
                                                         Scheme_Object *right_obj);
static Scheme_Object *pvector_insert_between_unsafe(Scheme_Object *left_obj,
                                                    Scheme_Object *value,
                                                    Scheme_Object *right_obj);
static void pvector_pop_left_unsafe(Scheme_Object *pv_obj,
                                    Scheme_Object **out_value,
                                    Scheme_Object **out_rest);
static void pvector_pop_right_unsafe(Scheme_Object *pv_obj,
                                     Scheme_Object **out_value,
                                     Scheme_Object **out_rest);
static Scheme_Object *node_tree_take_unsafe(Scheme_Object *node_obj,
                                            intptr_t pos);
static Scheme_Object *node_tree_drop_unsafe(Scheme_Object *node_obj,
                                            intptr_t pos);
static void node_tree_split_at_unsafe(Scheme_Object *node_obj, intptr_t pos,
                                      Scheme_Object **out_left,
                                      Scheme_Object **out_right);
static void pvector_split_at_unsafe(Scheme_Object *pv_obj, intptr_t pos,
                                    Scheme_Object **out_left,
                                    Scheme_Object **out_right);

static Scheme_Object *
make_pvector_object(int shape, intptr_t len,
                    Scheme_Object *a, Scheme_Object *b,
                    Scheme_Object *c, Scheme_Object *d,
                    int prefix_len, int suffix_len)
{
  Scheme_PVector *pv;

  pv = (Scheme_PVector *)scheme_malloc_tagged(sizeof(Scheme_PVector));
  pv->iso.so.type = scheme_pvector_type;
  pv->length = len;
  pv->shape = shape;
  pv->prefix_len = prefix_len;
  pv->suffix_len = suffix_len;
  pv->reserved = 0;
  pv->a = a;
  pv->b = b;
  pv->c = c;
  pv->d = d;

  return (Scheme_Object *)pv;
}

static Scheme_Object *
make_single_pvector(Scheme_Object *v)
{
  return make_pvector_object(SCHEME_PVECTOR_SINGLE, 1,
                             v, NULL, NULL, NULL,
                             0, 0);
}

static Scheme_Object *
make_deep_pvector(intptr_t len, Scheme_Object *prefix,
                  Scheme_Object *middle, Scheme_Object *suffix,
                  int prefix_len, int suffix_len)
{
  return make_pvector_object(SCHEME_PVECTOR_DEEP, len,
                             prefix, middle, suffix, NULL,
                             prefix_len, suffix_len);
}

static Scheme_Object *
make_digit_from_args(Scheme_Object **argv, intptr_t start, int count)
{
  Scheme_PVector_Digit *digit;
  int i;

  digit = (Scheme_PVector_Digit *)scheme_malloc_tagged(sizeof(Scheme_PVector_Digit));
  digit->so.type = scheme_pvector_node_type;
  digit->kind = SCHEME_PVECTOR_NODE_DIGIT;
  digit->count = count;
  digit->level = 0;
  for (i = 0; i < count; i++) {
    digit->els[i] = argv[start + i];
  }
  for (; i < 4; i++) {
    digit->els[i] = NULL;
  }

  return (Scheme_Object *)digit;
}

static Scheme_Object *
make_digit_from_vector(Scheme_Object *vec, intptr_t start, int count)
{
  Scheme_PVector_Digit *digit;
  int i;

  digit = (Scheme_PVector_Digit *)scheme_malloc_tagged(sizeof(Scheme_PVector_Digit));
  digit->so.type = scheme_pvector_node_type;
  digit->kind = SCHEME_PVECTOR_NODE_DIGIT;
  digit->count = count;
  digit->level = 0;
  for (i = 0; i < count; i++) {
    digit->els[i] = SCHEME_VEC_ELS(vec)[start + i];
  }
  for (; i < 4; i++) {
    digit->els[i] = NULL;
  }

  return (Scheme_Object *)digit;
}

static Scheme_Object *
make_digit_from_list(Scheme_Object **list, int count)
{
  Scheme_PVector_Digit *digit;
  int i;

  digit = (Scheme_PVector_Digit *)scheme_malloc_tagged(sizeof(Scheme_PVector_Digit));
  digit->so.type = scheme_pvector_node_type;
  digit->kind = SCHEME_PVECTOR_NODE_DIGIT;
  digit->count = count;
  digit->level = 0;
  for (i = 0; i < count; i++) {
    digit->els[i] = SCHEME_CAR(*list);
    *list = SCHEME_CDR(*list);
  }
  for (; i < 4; i++) {
    digit->els[i] = NULL;
  }

  return (Scheme_Object *)digit;
}

static Scheme_Object *
make_digit_from_fields(int count,
                       Scheme_Object *a, Scheme_Object *b,
                       Scheme_Object *c, Scheme_Object *d)
{
  Scheme_PVector_Digit *digit;

  digit = (Scheme_PVector_Digit *)scheme_malloc_tagged(sizeof(Scheme_PVector_Digit));
  digit->so.type = scheme_pvector_node_type;
  digit->kind = SCHEME_PVECTOR_NODE_DIGIT;
  digit->count = count;
  digit->level = 0;
  digit->els[0] = (count > 0) ? a : NULL;
  digit->els[1] = (count > 1) ? b : NULL;
  digit->els[2] = (count > 2) ? c : NULL;
  digit->els[3] = (count > 3) ? d : NULL;

  return (Scheme_Object *)digit;
}

static Scheme_Object *
make_digit_constant(int count, Scheme_Object *value)
{
  return make_digit_from_fields(count, value, value, value, value);
}

static Scheme_Object *
make_digit_with_replaced(Scheme_Object *digit_obj, int index, Scheme_Object *value)
{
  Scheme_PVector_Digit *old_digit, *digit;
  int i, count;

  old_digit = (Scheme_PVector_Digit *)digit_obj;
  count = old_digit->count;
  digit = (Scheme_PVector_Digit *)scheme_malloc_tagged(sizeof(Scheme_PVector_Digit));
  digit->so.type = scheme_pvector_node_type;
  digit->kind = SCHEME_PVECTOR_NODE_DIGIT;
  digit->count = count;
  digit->level = 0;
  for (i = 0; i < count; i++) {
    digit->els[i] = ((i == index) ? value : old_digit->els[i]);
  }
  for (; i < 4; i++) {
    digit->els[i] = NULL;
  }

  return (Scheme_Object *)digit;
}

static Scheme_Object *
make_digit_with_prepended(Scheme_Object *digit_obj, Scheme_Object *value)
{
  Scheme_PVector_Digit *old_digit;
  int count;

  old_digit = (Scheme_PVector_Digit *)digit_obj;
  count = old_digit->count;
  if (count >= 4) {
    scheme_signal_error("internal error: pvector prefix digit is full");
    return NULL;
  }

  if (count == 1) {
    return make_digit_from_fields(2, value, old_digit->els[0], NULL, NULL);
  } else if (count == 2) {
    return make_digit_from_fields(3, value, old_digit->els[0], old_digit->els[1], NULL);
  } else {
    return make_digit_from_fields(4, value, old_digit->els[0], old_digit->els[1], old_digit->els[2]);
  }
}

static Scheme_Object *
make_digit_with_appended(Scheme_Object *digit_obj, Scheme_Object *value)
{
  Scheme_PVector_Digit *old_digit;
  int count;

  old_digit = (Scheme_PVector_Digit *)digit_obj;
  count = old_digit->count;
  if (count >= 4) {
    scheme_signal_error("internal error: pvector suffix digit is full");
    return NULL;
  }

  if (count == 1) {
    return make_digit_from_fields(2, old_digit->els[0], value, NULL, NULL);
  } else if (count == 2) {
    return make_digit_from_fields(3, old_digit->els[0], old_digit->els[1], value, NULL);
  } else {
    return make_digit_from_fields(4, old_digit->els[0], old_digit->els[1], old_digit->els[2], value);
  }
}

static Scheme_Object *
make_digit_without_first(Scheme_Object *digit_obj)
{
  Scheme_PVector_Digit *old_digit;
  int count;

  old_digit = (Scheme_PVector_Digit *)digit_obj;
  count = old_digit->count;
  if (count <= 1) {
    scheme_signal_error("internal error: pvector prefix digit has no rest");
    return NULL;
  }

  if (count == 2) {
    return make_digit_from_fields(1, old_digit->els[1], NULL, NULL, NULL);
  } else if (count == 3) {
    return make_digit_from_fields(2, old_digit->els[1], old_digit->els[2], NULL, NULL);
  } else {
    return make_digit_from_fields(3, old_digit->els[1], old_digit->els[2], old_digit->els[3], NULL);
  }
}

static Scheme_Object *
make_digit_without_last(Scheme_Object *digit_obj)
{
  Scheme_PVector_Digit *old_digit;
  int count;

  old_digit = (Scheme_PVector_Digit *)digit_obj;
  count = old_digit->count;
  if (count <= 1) {
    scheme_signal_error("internal error: pvector suffix digit has no rest");
    return NULL;
  }

  if (count == 2) {
    return make_digit_from_fields(1, old_digit->els[0], NULL, NULL, NULL);
  } else if (count == 3) {
    return make_digit_from_fields(2, old_digit->els[0], old_digit->els[1], NULL, NULL);
  } else {
    return make_digit_from_fields(3, old_digit->els[0], old_digit->els[1], old_digit->els[2], NULL);
  }
}

static Scheme_Object *
make_digit_from_leaf_node(Scheme_Object *node_obj)
{
  Scheme_PVector_Node *node = (Scheme_PVector_Node *)node_obj;

  if (node->level != 0) {
    scheme_signal_error("internal error: pvector edge refill did not reach a leaf node");
    return NULL;
  }

  if (node->arity == 2) {
    return make_digit_from_fields(2, node->a, node->b, NULL, NULL);
  } else {
    return make_digit_from_fields(3, node->a, node->b, node->c, NULL);
  }
}

static Scheme_Object *
make_digit_from_value_and_leaf_node(Scheme_Object *value, Scheme_Object *node_obj)
{
  Scheme_PVector_Node *node = (Scheme_PVector_Node *)node_obj;

  if (node->level != 0) {
    scheme_signal_error("internal error: pvector edge prepend did not reach a leaf node");
    return NULL;
  }

  if (node->arity == 2) {
    return make_digit_from_fields(3, value, node->a, node->b, NULL);
  } else {
    return make_digit_from_fields(4, value, node->a, node->b, node->c);
  }
}

static Scheme_Object *
make_digit_from_leaf_node_and_value(Scheme_Object *node_obj, Scheme_Object *value)
{
  Scheme_PVector_Node *node = (Scheme_PVector_Node *)node_obj;

  if (node->level != 0) {
    scheme_signal_error("internal error: pvector edge append did not reach a leaf node");
    return NULL;
  }

  if (node->arity == 2) {
    return make_digit_from_fields(3, node->a, node->b, value, NULL);
  } else {
    return make_digit_from_fields(4, node->a, node->b, node->c, value);
  }
}

XFORM_NONGCING static intptr_t
pvector_child_measure(Scheme_Object *v)
{
  if (SCHEME_PVECTOR_NODEP(v)
      && (SCHEME_PVECTOR_NODE_KIND(v) == SCHEME_PVECTOR_NODE_TREE)) {
    return SCHEME_PVECTOR_NODE_MEASURE(v);
  } else {
    return 1;
  }
}

static Scheme_Object *
make_node2(int level, Scheme_Object *a, Scheme_Object *b)
{
  Scheme_PVector_Node *node;

  node = (Scheme_PVector_Node *)scheme_malloc_tagged(sizeof(Scheme_PVector_Node));
  node->so.type = scheme_pvector_node_type;
  node->kind = SCHEME_PVECTOR_NODE_TREE;
  node->arity = 2;
  node->level = level;
  node->measure = pvector_child_measure(a) + pvector_child_measure(b);
  node->a = a;
  node->b = b;
  node->c = NULL;

  return (Scheme_Object *)node;
}

static Scheme_Object *
make_node3(int level, Scheme_Object *a, Scheme_Object *b, Scheme_Object *c)
{
  Scheme_PVector_Node *node;

  node = (Scheme_PVector_Node *)scheme_malloc_tagged(sizeof(Scheme_PVector_Node));
  node->so.type = scheme_pvector_node_type;
  node->kind = SCHEME_PVECTOR_NODE_TREE;
  node->arity = 3;
  node->level = level;
  node->measure = (pvector_child_measure(a)
                   + pvector_child_measure(b)
                   + pvector_child_measure(c));
  node->a = a;
  node->b = b;
  node->c = c;

  return (Scheme_Object *)node;
}

static int
node_cons_left(Scheme_Object *node_obj, Scheme_Object *value,
               Scheme_Object **out_left, Scheme_Object **out_right)
{
  Scheme_PVector_Node *node = (Scheme_PVector_Node *)node_obj;
  Scheme_Object *left = NULL, *right = NULL;
  Scheme_Object *child_left = NULL, *child_right = NULL;

  if (node->level == 0) {
    if (node->arity == 2) {
      left = make_node3(0, value, node->a, node->b);
      *out_left = left;
      *out_right = NULL;
      return 0;
    } else {
      left = make_node2(0, value, node->a);
      right = make_node2(0, node->b, node->c);
      *out_left = left;
      *out_right = right;
      return 1;
    }
  }

  if (node_cons_left(node->a, value, &child_left, &child_right)) {
    if (node->arity == 2) {
      left = make_node3(node->level, child_left, child_right, node->b);
      *out_left = left;
      *out_right = NULL;
      return 0;
    } else {
      left = make_node2(node->level, child_left, child_right);
      right = make_node2(node->level, node->b, node->c);
      *out_left = left;
      *out_right = right;
      return 1;
    }
  } else {
    if (node->arity == 2) {
      left = make_node2(node->level, child_left, node->b);
    } else {
      left = make_node3(node->level, child_left, node->b, node->c);
    }
    *out_left = left;
    *out_right = NULL;
    return 0;
  }
}

static int
node_cons_right(Scheme_Object *node_obj, Scheme_Object *value,
                Scheme_Object **out_left, Scheme_Object **out_right)
{
  Scheme_PVector_Node *node = (Scheme_PVector_Node *)node_obj;
  Scheme_Object *left = NULL, *right = NULL;
  Scheme_Object *child_left = NULL, *child_right = NULL;

  if (node->level == 0) {
    if (node->arity == 2) {
      left = make_node3(0, node->a, node->b, value);
      *out_left = left;
      *out_right = NULL;
      return 0;
    } else {
      left = make_node2(0, node->a, node->b);
      right = make_node2(0, node->c, value);
      *out_left = left;
      *out_right = right;
      return 1;
    }
  }

  if (node->arity == 2) {
    if (node_cons_right(node->b, value, &child_left, &child_right)) {
      left = make_node3(node->level, node->a, child_left, child_right);
      *out_left = left;
      *out_right = NULL;
      return 0;
    } else {
      left = make_node2(node->level, node->a, child_left);
      *out_left = left;
      *out_right = NULL;
      return 0;
    }
  } else {
    if (node_cons_right(node->c, value, &child_left, &child_right)) {
      left = make_node2(node->level, node->a, node->b);
      right = make_node2(node->level, child_left, child_right);
      *out_left = left;
      *out_right = right;
      return 1;
    } else {
      left = make_node3(node->level, node->a, node->b, child_left);
      *out_left = left;
      *out_right = NULL;
      return 0;
    }
  }
}

static Scheme_Object *
node_tree_cons_left(Scheme_Object *middle, Scheme_Object *value)
{
  Scheme_Object *left = NULL, *right = NULL;
  Scheme_PVector_Node *node;

  if (SCHEME_FALSEP(middle)) {
    scheme_signal_error("internal error: cannot insert one item into empty pvector middle tree");
    return NULL;
  }

  node = (Scheme_PVector_Node *)middle;
  if (node_cons_left(middle, value, &left, &right)) {
    return make_node2(node->level + 1, left, right);
  } else {
    return left;
  }
}

static Scheme_Object *
node_tree_cons_right(Scheme_Object *middle, Scheme_Object *value)
{
  Scheme_Object *left = NULL, *right = NULL;
  Scheme_PVector_Node *node;

  if (SCHEME_FALSEP(middle)) {
    scheme_signal_error("internal error: cannot insert one item into empty pvector middle tree");
    return NULL;
  }

  node = (Scheme_PVector_Node *)middle;
  if (node_cons_right(middle, value, &left, &right)) {
    return make_node2(node->level + 1, left, right);
  } else {
    return left;
  }
}

static Scheme_Object *
node_tree_prepend3(Scheme_Object *middle,
                   Scheme_Object *a, Scheme_Object *b, Scheme_Object *c)
{
  if (SCHEME_FALSEP(middle)) {
    return make_node3(0, a, b, c);
  } else {
    middle = node_tree_cons_left(middle, c);
    middle = node_tree_cons_left(middle, b);
    return node_tree_cons_left(middle, a);
  }
}

static Scheme_Object *
node_tree_append3(Scheme_Object *middle,
                  Scheme_Object *a, Scheme_Object *b, Scheme_Object *c)
{
  if (SCHEME_FALSEP(middle)) {
    return make_node3(0, a, b, c);
  } else {
    middle = node_tree_cons_right(middle, a);
    middle = node_tree_cons_right(middle, b);
    return node_tree_cons_right(middle, c);
  }
}

static void
node_tree_pop_left_leaf(Scheme_Object *middle,
                        Scheme_Object **out_leaf, Scheme_Object **out_rest)
{
  Scheme_PVector_Node *node = (Scheme_PVector_Node *)middle;
  Scheme_Object *leaf = NULL, *child_rest = NULL, *rest = NULL;

  if (node->level == 0) {
    *out_leaf = middle;
    *out_rest = scheme_false;
    return;
  }

  node_tree_pop_left_leaf(node->a, &leaf, &child_rest);
  if (SCHEME_FALSEP(child_rest)) {
    if (node->arity == 2) {
      rest = node->b;
    } else {
      rest = make_node2(node->level, node->b, node->c);
    }
  } else {
    if (node->arity == 2) {
      rest = make_node2(node->level, child_rest, node->b);
    } else {
      rest = make_node3(node->level, child_rest, node->b, node->c);
    }
  }

  *out_leaf = leaf;
  *out_rest = rest;
}

static void
node_tree_pop_right_leaf(Scheme_Object *middle,
                         Scheme_Object **out_leaf, Scheme_Object **out_rest)
{
  Scheme_PVector_Node *node = (Scheme_PVector_Node *)middle;
  Scheme_Object *leaf = NULL, *child_rest = NULL, *rest = NULL;

  if (node->level == 0) {
    *out_leaf = middle;
    *out_rest = scheme_false;
    return;
  }

  if (node->arity == 2) {
    node_tree_pop_right_leaf(node->b, &leaf, &child_rest);
    if (SCHEME_FALSEP(child_rest)) {
      rest = node->a;
    } else {
      rest = make_node2(node->level, node->a, child_rest);
    }
  } else {
    node_tree_pop_right_leaf(node->c, &leaf, &child_rest);
    if (SCHEME_FALSEP(child_rest)) {
      rest = make_node2(node->level, node->a, node->b);
    } else {
      rest = make_node3(node->level, node->a, node->b, child_rest);
    }
  }

  *out_leaf = leaf;
  *out_rest = rest;
}

static Scheme_Object *
node_tree_from_fields(int count,
                      Scheme_Object *a, Scheme_Object *b,
                      Scheme_Object *c, Scheme_Object *d,
                      Scheme_Object *e, Scheme_Object *f,
                      Scheme_Object *g, Scheme_Object *h,
                      Scheme_Object *i)
{
  Scheme_Object *n1, *n2, *n3;

  if (count == 2) {
    return make_node2(0, a, b);
  } else if (count == 3) {
    return make_node3(0, a, b, c);
  } else if (count == 4) {
    n1 = make_node2(0, a, b);
    n2 = make_node2(0, c, d);
    return make_node2(1, n1, n2);
  } else if (count == 5) {
    n1 = make_node3(0, a, b, c);
    n2 = make_node2(0, d, e);
    return make_node2(1, n1, n2);
  } else if (count == 6) {
    n1 = make_node3(0, a, b, c);
    n2 = make_node3(0, d, e, f);
    return make_node2(1, n1, n2);
  } else if (count == 7) {
    n1 = make_node2(0, a, b);
    n2 = make_node3(0, c, d, e);
    n3 = make_node2(0, f, g);
    return make_node3(1, n1, n2, n3);
  } else if (count == 8) {
    n1 = make_node3(0, a, b, c);
    n2 = make_node3(0, d, e, f);
    n3 = make_node2(0, g, h);
    return make_node3(1, n1, n2, n3);
  } else if (count == 9) {
    n1 = make_node3(0, a, b, c);
    n2 = make_node3(0, d, e, f);
    n3 = make_node3(0, g, h, i);
    return make_node3(1, n1, n2, n3);
  } else {
    scheme_signal_error("internal error: pvector append bridge arity is not 2..9");
    return NULL;
  }
}

static Scheme_Object *
node_tree_from_digit_pair(Scheme_Object *left_digit_obj, Scheme_Object *right_digit_obj)
{
  Scheme_PVector_Digit *left_digit = (Scheme_PVector_Digit *)left_digit_obj;
  Scheme_PVector_Digit *right_digit = (Scheme_PVector_Digit *)right_digit_obj;
  Scheme_Object *v0 = NULL, *v1 = NULL, *v2 = NULL, *v3 = NULL;
  Scheme_Object *v4 = NULL, *v5 = NULL, *v6 = NULL, *v7 = NULL;
  int total = left_digit->count + right_digit->count;
  int i, pos = 0;

  for (i = 0; i < left_digit->count; i++) {
    if (pos == 0) v0 = left_digit->els[i];
    else if (pos == 1) v1 = left_digit->els[i];
    else if (pos == 2) v2 = left_digit->els[i];
    else if (pos == 3) v3 = left_digit->els[i];
    else if (pos == 4) v4 = left_digit->els[i];
    else if (pos == 5) v5 = left_digit->els[i];
    else if (pos == 6) v6 = left_digit->els[i];
    else v7 = left_digit->els[i];
    pos++;
  }
  for (i = 0; i < right_digit->count; i++) {
    if (pos == 0) v0 = right_digit->els[i];
    else if (pos == 1) v1 = right_digit->els[i];
    else if (pos == 2) v2 = right_digit->els[i];
    else if (pos == 3) v3 = right_digit->els[i];
    else if (pos == 4) v4 = right_digit->els[i];
    else if (pos == 5) v5 = right_digit->els[i];
    else if (pos == 6) v6 = right_digit->els[i];
    else v7 = right_digit->els[i];
    pos++;
  }

  return node_tree_from_fields(total, v0, v1, v2, v3, v4, v5, v6, v7, NULL);
}

static Scheme_Object *
node_tree_from_digit_value_digit(Scheme_Object *left_digit_obj,
                                 Scheme_Object *value,
                                 Scheme_Object *right_digit_obj)
{
  Scheme_PVector_Digit *left_digit = (Scheme_PVector_Digit *)left_digit_obj;
  Scheme_PVector_Digit *right_digit = (Scheme_PVector_Digit *)right_digit_obj;
  Scheme_Object *v0 = NULL, *v1 = NULL, *v2 = NULL, *v3 = NULL;
  Scheme_Object *v4 = NULL, *v5 = NULL, *v6 = NULL, *v7 = NULL, *v8 = NULL;
  int total = left_digit->count + 1 + right_digit->count;
  int i, pos = 0;

  for (i = 0; i < left_digit->count; i++) {
    if (pos == 0) v0 = left_digit->els[i];
    else if (pos == 1) v1 = left_digit->els[i];
    else if (pos == 2) v2 = left_digit->els[i];
    else if (pos == 3) v3 = left_digit->els[i];
    else if (pos == 4) v4 = left_digit->els[i];
    else if (pos == 5) v5 = left_digit->els[i];
    else if (pos == 6) v6 = left_digit->els[i];
    else if (pos == 7) v7 = left_digit->els[i];
    else v8 = left_digit->els[i];
    pos++;
  }

  if (pos == 0) v0 = value;
  else if (pos == 1) v1 = value;
  else if (pos == 2) v2 = value;
  else if (pos == 3) v3 = value;
  else if (pos == 4) v4 = value;
  else if (pos == 5) v5 = value;
  else if (pos == 6) v6 = value;
  else if (pos == 7) v7 = value;
  else v8 = value;
  pos++;

  for (i = 0; i < right_digit->count; i++) {
    if (pos == 0) v0 = right_digit->els[i];
    else if (pos == 1) v1 = right_digit->els[i];
    else if (pos == 2) v2 = right_digit->els[i];
    else if (pos == 3) v3 = right_digit->els[i];
    else if (pos == 4) v4 = right_digit->els[i];
    else if (pos == 5) v5 = right_digit->els[i];
    else if (pos == 6) v6 = right_digit->els[i];
    else if (pos == 7) v7 = right_digit->els[i];
    else v8 = right_digit->els[i];
    pos++;
  }

  return node_tree_from_fields(total, v0, v1, v2, v3, v4, v5, v6, v7, v8);
}

static int
node_append_subtree(Scheme_Object *node_obj, Scheme_Object *value,
                    Scheme_Object **out_left, Scheme_Object **out_right)
{
  Scheme_PVector_Node *node = (Scheme_PVector_Node *)node_obj;
  Scheme_Object *left = NULL, *right = NULL;
  Scheme_Object *child_left = NULL, *child_right = NULL;
  int value_level, child_level;

  value_level = SCHEME_PVECTOR_NODE_LEVEL(value);
  child_level = SCHEME_PVECTOR_NODE_LEVEL((node->arity == 2) ? node->b : node->c);
  if ((node->level == value_level + 1)
      || (child_level <= value_level)) {
    if (node->arity == 2) {
      left = make_node3(node->level, node->a, node->b, value);
      *out_left = left;
      *out_right = NULL;
      return 0;
    } else {
      left = make_node2(node->level, node->a, node->b);
      right = make_node2(node->level, node->c, value);
      *out_left = left;
      *out_right = right;
      return 1;
    }
  } else if (node->level <= value_level) {
    scheme_signal_error("internal error: pvector append subtree level mismatch");
    return 0;
  }

  if (node->arity == 2) {
    if (node_append_subtree(node->b, value, &child_left, &child_right)) {
      left = make_node3(node->level, node->a, child_left, child_right);
    } else {
      left = make_node2(node->level, node->a, child_left);
    }
    *out_left = left;
    *out_right = NULL;
    return 0;
  } else {
    if (node_append_subtree(node->c, value, &child_left, &child_right)) {
      left = make_node2(node->level, node->a, node->b);
      right = make_node2(node->level, child_left, child_right);
      *out_left = left;
      *out_right = right;
      return 1;
    } else {
      left = make_node3(node->level, node->a, node->b, child_left);
      *out_left = left;
      *out_right = NULL;
      return 0;
    }
  }
}

static int
node_prepend_subtree(Scheme_Object *node_obj, Scheme_Object *value,
                     Scheme_Object **out_left, Scheme_Object **out_right)
{
  Scheme_PVector_Node *node = (Scheme_PVector_Node *)node_obj;
  Scheme_Object *left = NULL, *right = NULL;
  Scheme_Object *child_left = NULL, *child_right = NULL;
  int value_level, child_level;

  value_level = SCHEME_PVECTOR_NODE_LEVEL(value);
  child_level = SCHEME_PVECTOR_NODE_LEVEL(node->a);
  if ((node->level == value_level + 1)
      || (child_level <= value_level)) {
    if (node->arity == 2) {
      left = make_node3(node->level, value, node->a, node->b);
      *out_left = left;
      *out_right = NULL;
      return 0;
    } else {
      left = make_node2(node->level, value, node->a);
      right = make_node2(node->level, node->b, node->c);
      *out_left = left;
      *out_right = right;
      return 1;
    }
  } else if (node->level <= value_level) {
    scheme_signal_error("internal error: pvector prepend subtree level mismatch");
    return 0;
  }

  if (node_prepend_subtree(node->a, value, &child_left, &child_right)) {
    if (node->arity == 2) {
      left = make_node3(node->level, child_left, child_right, node->b);
      *out_left = left;
      *out_right = NULL;
      return 0;
    } else {
      left = make_node2(node->level, child_left, child_right);
      right = make_node2(node->level, node->b, node->c);
      *out_left = left;
      *out_right = right;
      return 1;
    }
  } else {
    if (node->arity == 2) {
      left = make_node2(node->level, child_left, node->b);
    } else {
      left = make_node3(node->level, child_left, node->b, node->c);
    }
    *out_left = left;
    *out_right = NULL;
    return 0;
  }
}

static Scheme_Object *
node_tree_join(Scheme_Object *left_obj, Scheme_Object *right_obj)
{
  Scheme_Object *left = NULL, *right = NULL;
  int left_level, right_level;

  if (SCHEME_FALSEP(left_obj)) {
    return right_obj;
  } else if (SCHEME_FALSEP(right_obj)) {
    return left_obj;
  }

  left_level = SCHEME_PVECTOR_NODE_LEVEL(left_obj);
  right_level = SCHEME_PVECTOR_NODE_LEVEL(right_obj);
  if (left_level == right_level) {
    return make_node2(left_level + 1, left_obj, right_obj);
  } else if (left_level > right_level) {
    if (node_append_subtree(left_obj, right_obj, &left, &right)) {
      return make_node2(left_level + 1, left, right);
    } else {
      return left;
    }
  } else {
    if (node_prepend_subtree(right_obj, left_obj, &left, &right)) {
      return make_node2(right_level + 1, left, right);
    } else {
      return left;
    }
  }
}

XFORM_NONGCING static int
next_group_size(intptr_t remaining)
{
  if (remaining <= 3) {
    return (int)remaining;
  } else if (remaining == 4) {
    return 2;
  } else if ((remaining % 3) == 1) {
    return 2;
  } else {
    return 3;
  }
}

XFORM_NONGCING static intptr_t
node_group_count(intptr_t count)
{
  intptr_t groups = 0;
  intptr_t remaining = count;
  int group;

  while (remaining > 0) {
    group = next_group_size(remaining);
    groups++;
    remaining -= group;
  }

  return groups;
}

static Scheme_Object *
make_node_from_args(Scheme_Object **argv, intptr_t start, int count, int level)
{
  if (count == 2) {
    return make_node2(level, argv[start], argv[start + 1]);
  } else if (count == 3) {
    return make_node3(level, argv[start], argv[start + 1], argv[start + 2]);
  } else {
    scheme_signal_error("internal error: pvector node arity is not 2 or 3");
    return NULL;
  }
}

static Scheme_Object **
make_node_array(intptr_t count)
{
  Scheme_Object **nodes;
  intptr_t i;

  nodes = MALLOC_N(Scheme_Object *, count);
  for (i = 0; i < count; i++) {
    nodes[i] = NULL;
  }

  return nodes;
}

static Scheme_Object *
build_node_tree_from_array(Scheme_Object **nodes, intptr_t start,
                           intptr_t count, int level)
{
  Scheme_Object **next_nodes;
  Scheme_Object *node;
  intptr_t groups, group_index, pos, remaining;
  int group;

  if (count == 0) {
    return scheme_false;
  } else if (count == 1) {
    scheme_signal_error("internal error: pvector middle tree cannot contain one item");
    return NULL;
  } else if (count <= 3) {
    return make_node_from_args(nodes, start, (int)count, level);
  }

  groups = node_group_count(count);
  next_nodes = make_node_array(groups);
  group_index = 0;
  pos = start;
  remaining = count;

  while (remaining > 0) {
    group = next_group_size(remaining);
    node = make_node_from_args(nodes, pos, group, level);
    next_nodes[group_index] = node;
    group_index++;
    pos += group;
    remaining -= group;
  }

  return build_node_tree_from_array(next_nodes, 0, groups, level + 1);
}

static Scheme_Object *
make_node_from_vector(Scheme_Object *vec, intptr_t start, int count, int level)
{
  if (count == 2) {
    return make_node2(level,
                      SCHEME_VEC_ELS(vec)[start],
                      SCHEME_VEC_ELS(vec)[start + 1]);
  } else if (count == 3) {
    return make_node3(level,
                      SCHEME_VEC_ELS(vec)[start],
                      SCHEME_VEC_ELS(vec)[start + 1],
                      SCHEME_VEC_ELS(vec)[start + 2]);
  } else {
    scheme_signal_error("internal error: pvector node arity is not 2 or 3");
    return NULL;
  }
}

static Scheme_Object *
make_node_from_list(Scheme_Object **list, int count, int level)
{
  Scheme_Object *a, *b, *c = NULL;

  a = SCHEME_CAR(*list);
  *list = SCHEME_CDR(*list);
  b = SCHEME_CAR(*list);
  *list = SCHEME_CDR(*list);
  if (count == 3) {
    c = SCHEME_CAR(*list);
    *list = SCHEME_CDR(*list);
    return make_node3(level, a, b, c);
  } else if (count == 2) {
    return make_node2(level, a, b);
  } else {
    scheme_signal_error("internal error: pvector list node arity is not 2 or 3");
    return NULL;
  }
}

static Scheme_Object *
make_node_constant(int count, int level, Scheme_Object *value)
{
  if (count == 2) {
    return make_node2(level, value, value);
  } else if (count == 3) {
    return make_node3(level, value, value, value);
  } else {
    scheme_signal_error("internal error: pvector repeated node arity is not 2 or 3");
    return NULL;
  }
}

static Scheme_Object *
build_node_tree_from_vector(Scheme_Object *vec, intptr_t start,
                            intptr_t count, int level)
{
  Scheme_Object **next_nodes;
  Scheme_Object *node;
  intptr_t groups, group_index, pos, remaining;
  int group;

  if (count == 0) {
    return scheme_false;
  } else if (count == 1) {
    scheme_signal_error("internal error: pvector middle tree cannot contain one item");
    return NULL;
  } else if (count <= 3) {
    return make_node_from_vector(vec, start, (int)count, level);
  }

  groups = node_group_count(count);
  next_nodes = make_node_array(groups);
  group_index = 0;
  pos = start;
  remaining = count;

  while (remaining > 0) {
    group = next_group_size(remaining);
    node = make_node_from_vector(vec, pos, group, level);
    next_nodes[group_index] = node;
    group_index++;
    pos += group;
    remaining -= group;
  }

  return build_node_tree_from_array(next_nodes, 0, groups, level + 1);
}

static Scheme_Object *
build_node_tree_from_list(Scheme_Object **list, intptr_t count, int level)
{
  Scheme_Object **next_nodes;
  Scheme_Object *node;
  intptr_t groups, group_index, remaining;
  int group;

  if (count == 0) {
    return scheme_false;
  } else if (count == 1) {
    scheme_signal_error("internal error: pvector list middle tree cannot contain one item");
    return NULL;
  } else if (count <= 3) {
    return make_node_from_list(list, (int)count, level);
  }

  groups = node_group_count(count);
  next_nodes = make_node_array(groups);
  group_index = 0;
  remaining = count;

  while (remaining > 0) {
    group = next_group_size(remaining);
    node = make_node_from_list(list, group, level);
    next_nodes[group_index] = node;
    group_index++;
    remaining -= group;
  }

  return build_node_tree_from_array(next_nodes, 0, groups, level + 1);
}

static Scheme_Object *
build_node_tree_constant(intptr_t count, int level, Scheme_Object *value)
{
  Scheme_Object **next_nodes;
  Scheme_Object *node;
  intptr_t groups, group_index, remaining;
  int group;

  if (count == 0) {
    return scheme_false;
  } else if (count == 1) {
    scheme_signal_error("internal error: pvector repeated middle tree cannot contain one item");
    return NULL;
  } else if (count <= 3) {
    return make_node_constant((int)count, level, value);
  }

  groups = node_group_count(count);
  next_nodes = make_node_array(groups);
  group_index = 0;
  remaining = count;

  while (remaining > 0) {
    group = next_group_size(remaining);
    node = make_node_constant(group, level, value);
    next_nodes[group_index] = node;
    group_index++;
    remaining -= group;
  }

  return build_node_tree_from_array(next_nodes, 0, groups, level + 1);
}

static Scheme_Object *
build_node_tree_from_args(Scheme_Object **argv, intptr_t start,
                          intptr_t count, int level)
{
  Scheme_Object **next_nodes;
  Scheme_Object *node;
  intptr_t groups, group_index, pos, remaining;
  int group;

  if (count == 0) {
    return scheme_false;
  } else if (count == 1) {
    scheme_signal_error("internal error: pvector middle tree cannot contain one item");
    return NULL;
  } else if (count <= 3) {
    return make_node_from_args(argv, start, (int)count, level);
  }

  groups = node_group_count(count);
  next_nodes = make_node_array(groups);
  group_index = 0;
  pos = start;
  remaining = count;

  while (remaining > 0) {
    group = next_group_size(remaining);
    node = make_node_from_args(argv, pos, group, level);
    next_nodes[group_index] = node;
    group_index++;
    pos += group;
    remaining -= group;
  }

  return build_node_tree_from_array(next_nodes, 0, groups, level + 1);
}

static void
deep_edge_lengths(intptr_t len, int *_prefix_len, int *_suffix_len)
{
  if (len <= 8) {
    *_prefix_len = (int)(len / 2);
    *_suffix_len = (int)(len - *_prefix_len);
  } else {
    *_prefix_len = 4;
    *_suffix_len = (len == 9) ? 3 : 4;
  }
}

static Scheme_Object *
pvector_from_constant(intptr_t len, Scheme_Object *value)
{
  intptr_t middle_len;
  int prefix_len, suffix_len;
  Scheme_Object *prefix, *middle, *suffix;

  if (len <= 4) {
    return pvector_from_small_fields((int)len, value, value, value, value);
  }

  deep_edge_lengths(len, &prefix_len, &suffix_len);
  middle_len = len - prefix_len - suffix_len;
  prefix = make_digit_constant(prefix_len, value);
  suffix = make_digit_constant(suffix_len, value);
  middle = (middle_len ? build_node_tree_constant(middle_len, 0, value) : scheme_false);

  return make_deep_pvector(len, prefix, middle, suffix,
                           prefix_len, suffix_len);
}

static Scheme_Object *
pvector_from_args(int argc, Scheme_Object **argv)
{
  Scheme_Object *a = NULL, *b = NULL, *c = NULL, *d = NULL;
  int prefix_len, suffix_len;
  intptr_t middle_len;
  Scheme_Object *prefix, *middle, *suffix;

  if (argc <= 4) {
    if (argc > 0) a = argv[0];
    if (argc > 1) b = argv[1];
    if (argc > 2) c = argv[2];
    if (argc > 3) d = argv[3];
    return pvector_from_small_fields(argc, a, b, c, d);
  }

  deep_edge_lengths(argc, &prefix_len, &suffix_len);
  middle_len = argc - prefix_len - suffix_len;
  prefix = make_digit_from_args(argv, 0, prefix_len);
  suffix = make_digit_from_args(argv, argc - suffix_len, suffix_len);
  middle = (middle_len ? build_node_tree_from_args(argv, prefix_len, middle_len, 0) : scheme_false);

  return make_deep_pvector(argc, prefix, middle, suffix, prefix_len, suffix_len);
}

static Scheme_Object *
pvector_from_vector(Scheme_Object *vec)
{
  Scheme_Object *a = NULL, *b = NULL, *c = NULL, *d = NULL;
  intptr_t len, middle_len;
  int prefix_len, suffix_len;
  Scheme_Object *prefix, *middle, *suffix;

  len = SCHEME_VEC_SIZE(vec);
  if (len <= 4) {
    if (len > 0) a = SCHEME_VEC_ELS(vec)[0];
    if (len > 1) b = SCHEME_VEC_ELS(vec)[1];
    if (len > 2) c = SCHEME_VEC_ELS(vec)[2];
    if (len > 3) d = SCHEME_VEC_ELS(vec)[3];
    return pvector_from_small_fields((int)len, a, b, c, d);
  }

  deep_edge_lengths(len, &prefix_len, &suffix_len);
  middle_len = len - prefix_len - suffix_len;
  prefix = make_digit_from_vector(vec, 0, prefix_len);
  suffix = make_digit_from_vector(vec, len - suffix_len, suffix_len);
  middle = (middle_len ? build_node_tree_from_vector(vec, prefix_len, middle_len, 0) : scheme_false);

  return make_deep_pvector(len, prefix, middle, suffix, prefix_len, suffix_len);
}

static Scheme_Object *
pvector_from_list(Scheme_Object *list)
{
  Scheme_Object *a = NULL, *b = NULL, *c = NULL, *d = NULL;
  intptr_t len, middle_len;
  int prefix_len, suffix_len;
  Scheme_Object *orig, *cursor, *prefix, *middle, *suffix;

  orig = list;
  len = scheme_proper_list_length(list);
  if (len < 0) {
    scheme_wrong_contract("core-list->pvector", "list?", 0, 1, &orig);
    return NULL;
  }

  cursor = list;
  if (len <= 4) {
    if (len > 0) {
      a = SCHEME_CAR(cursor);
      cursor = SCHEME_CDR(cursor);
    }
    if (len > 1) {
      b = SCHEME_CAR(cursor);
      cursor = SCHEME_CDR(cursor);
    }
    if (len > 2) {
      c = SCHEME_CAR(cursor);
      cursor = SCHEME_CDR(cursor);
    }
    if (len > 3) {
      d = SCHEME_CAR(cursor);
    }
    return pvector_from_small_fields((int)len, a, b, c, d);
  }

  deep_edge_lengths(len, &prefix_len, &suffix_len);
  middle_len = len - prefix_len - suffix_len;
  prefix = make_digit_from_list(&cursor, prefix_len);
  middle = (middle_len ? build_node_tree_from_list(&cursor, middle_len, 0) : scheme_false);
  suffix = make_digit_from_list(&cursor, suffix_len);

  return make_deep_pvector(len, prefix, middle, suffix,
                           prefix_len, suffix_len);
}

static Scheme_Object *
checked_pvector(const char *who, int argc, Scheme_Object **argv)
{
  if (!SCHEME_PVECTORP(argv[0])) {
    scheme_wrong_contract(who, "pvector?", 0, argc, argv);
    return NULL;
  }

  return argv[0];
}

static Scheme_Object *
checked_pvector_value(const char *who, Scheme_Object *value)
{
  Scheme_Object *argv[1];

  if (!SCHEME_PVECTORP(value)) {
    argv[0] = value;
    scheme_wrong_contract(who, "pvector?", 0, 1, argv);
    return NULL;
  }

  return value;
}

static intptr_t
checked_pvector_index_contract(const char *who, int argc, Scheme_Object **argv,
                               int pos, int *too_large)
{
  Scheme_Object *index_obj = argv[pos];

  *too_large = 0;

  if (SCHEME_INTP(index_obj)) {
    intptr_t index = SCHEME_INT_VAL(index_obj);
    if (index >= 0) {
      return index;
    }
  } else if (SCHEME_BIGNUMP(index_obj) && SCHEME_BIGPOS(index_obj)) {
    *too_large = 1;
    return 0;
  }

  scheme_wrong_contract(who, "exact-nonnegative-integer?", pos, argc, argv);
  return 0;
}

static Scheme_Object *
node_ref(Scheme_Object *node_obj, intptr_t index)
{
  Scheme_PVector_Node *node = (Scheme_PVector_Node *)node_obj;
  intptr_t a_measure, b_measure;

  if (node->level == 0) {
    if (index == 0) {
      return node->a;
    } else if (index == 1) {
      return node->b;
    } else {
      return node->c;
    }
  } else {
    a_measure = pvector_child_measure(node->a);
    if (index < a_measure) {
      return node_ref(node->a, index);
    } else {
      b_measure = pvector_child_measure(node->b);
      index -= a_measure;
      if ((node->arity == 2) || (index < b_measure)) {
        return node_ref(node->b, index);
      } else {
        return node_ref(node->c, index - b_measure);
      }
    }
  }
}

static Scheme_Object *
node_set(Scheme_Object *node_obj, intptr_t index, Scheme_Object *value)
{
  Scheme_PVector_Node *node = (Scheme_PVector_Node *)node_obj;
  Scheme_Object *a, *b, *c, *new_child;
  intptr_t a_measure, b_measure;

  if (node->level == 0) {
    if (index == 0) {
      if (SAME_OBJ(node->a, value)) {
        return node_obj;
      }
      a = value;
      b = node->b;
      c = node->c;
    } else if (index == 1) {
      if (SAME_OBJ(node->b, value)) {
        return node_obj;
      }
      a = node->a;
      b = value;
      c = node->c;
    } else if ((node->arity == 3) && (index == 2)) {
      if (SAME_OBJ(node->c, value)) {
        return node_obj;
      }
      a = node->a;
      b = node->b;
      c = value;
    } else {
      scheme_signal_error("internal error: pvector set missed leaf node");
      return NULL;
    }
  } else {
    a_measure = pvector_child_measure(node->a);
    if (index < a_measure) {
      new_child = node_set(node->a, index, value);
      if (SAME_OBJ(new_child, node->a)) {
        return node_obj;
      }
      a = new_child;
      b = node->b;
      c = node->c;
    } else {
      b_measure = pvector_child_measure(node->b);
      index -= a_measure;
      if ((node->arity == 2) || (index < b_measure)) {
        a = node->a;
        new_child = node_set(node->b, index, value);
        if (SAME_OBJ(new_child, node->b)) {
          return node_obj;
        }
        b = new_child;
        c = node->c;
      } else {
        a = node->a;
        b = node->b;
        new_child = node_set(node->c, index - b_measure, value);
        if (SAME_OBJ(new_child, node->c)) {
          return node_obj;
        }
        c = new_child;
      }
    }
  }

  if (node->arity == 2) {
    return make_node2(node->level, a, b);
  } else {
    return make_node3(node->level, a, b, c);
  }
}

static Scheme_Object *
pvector_ref_unsafe(Scheme_Object *pv_obj, intptr_t index)
{
  Scheme_PVector *pv = (Scheme_PVector *)pv_obj;
  Scheme_PVector_Digit *prefix, *suffix;
  intptr_t suffix_start;

  if (pv->shape == SCHEME_PVECTOR_SINGLE) {
    return pv->a;
  } else if (pv->shape == SCHEME_PVECTOR_DEEP) {
    prefix = (Scheme_PVector_Digit *)pv->a;
    if (index < prefix->count) {
      return prefix->els[index];
    }
    suffix = (Scheme_PVector_Digit *)pv->c;
    suffix_start = pv->length - suffix->count;
    if (index >= suffix_start) {
      return suffix->els[index - suffix_start];
    } else if (!SCHEME_FALSEP(pv->b)) {
      return node_ref(pv->b, index - prefix->count);
    } else {
      scheme_signal_error("internal error: pvector ref missed all deep fields");
      return NULL;
    }
  } else {
    scheme_signal_error("internal error: empty pvector has no element");
    return NULL;
  }
}

static Scheme_Object *
pvector_view_left_unsafe(Scheme_Object *pv_obj)
{
  Scheme_PVector *pv = (Scheme_PVector *)pv_obj;

  if (pv->shape == SCHEME_PVECTOR_SINGLE) {
    return pv->a;
  } else if (pv->shape == SCHEME_PVECTOR_DEEP) {
    Scheme_PVector_Digit *prefix = (Scheme_PVector_Digit *)pv->a;
    return prefix->els[0];
  } else {
    scheme_signal_error("internal error: empty pvector has no left view");
    return NULL;
  }
}

static Scheme_Object *
pvector_view_right_unsafe(Scheme_Object *pv_obj)
{
  Scheme_PVector *pv = (Scheme_PVector *)pv_obj;

  if (pv->shape == SCHEME_PVECTOR_SINGLE) {
    return pv->a;
  } else if (pv->shape == SCHEME_PVECTOR_DEEP) {
    Scheme_PVector_Digit *suffix = (Scheme_PVector_Digit *)pv->c;
    return suffix->els[suffix->count - 1];
  } else {
    scheme_signal_error("internal error: empty pvector has no right view");
    return NULL;
  }
}

Scheme_Object *
scheme_unsafe_pvector_ref(Scheme_Object *pv, Scheme_Object *index)
{
  return pvector_ref_unsafe(pv, SCHEME_INT_VAL(index));
}

static intptr_t
checked_pvector_index(const char *who, int argc, Scheme_Object **argv,
                      Scheme_Object *pv)
{
  intptr_t len, index;
  int too_large;

  index = checked_pvector_index_contract(who, argc, argv, 1, &too_large);
  len = SCHEME_PVECTOR_LENGTH(pv);

  if (too_large || (index >= len)) {
    scheme_out_of_range(who, "pvector", "", argv[1], pv, 0, len - 1);
    return 0;
  }

  return index;
}

static intptr_t
checked_pvector_index_after_contract(const char *who, int argc,
                                     Scheme_Object **argv, int pos,
                                     Scheme_Object *pv, intptr_t index,
                                     int too_large)
{
  intptr_t len;

  len = SCHEME_PVECTOR_LENGTH(pv);
  if (too_large || (index >= len)) {
    scheme_out_of_range(who, "pvector", "", argv[pos], pv, 0, len - 1);
    return 0;
  }

  return index;
}

static intptr_t
checked_pvector_index_value(const char *who, Scheme_Object *pv,
                            Scheme_Object *index_obj)
{
  Scheme_Object *argv[2];

  argv[0] = pv;
  argv[1] = index_obj;
  return checked_pvector_index(who, 2, argv, pv);
}

static intptr_t
checked_pvector_position(const char *who, int pos, int argc, Scheme_Object **argv,
                         Scheme_Object *pv)
{
  intptr_t len, index;
  int too_large;

  index = checked_pvector_index_contract(who, argc, argv, pos, &too_large);
  len = SCHEME_PVECTOR_LENGTH(pv);
  if (too_large || (index > len)) {
    scheme_out_of_range(who, "pvector", "", argv[pos], pv, 0, len);
    return 0;
  }

  return index;
}

static intptr_t
checked_pvector_position_after_contract(const char *who, int pos, int argc,
                                        Scheme_Object **argv,
                                        Scheme_Object *pv, intptr_t index,
                                        int too_large)
{
  intptr_t len;

  len = SCHEME_PVECTOR_LENGTH(pv);
  if (too_large || (index > len)) {
    scheme_out_of_range(who, "pvector", "", argv[pos], pv, 0, len);
    return 0;
  }

  return index;
}

static void
checked_pvector_range(const char *who, int argc, Scheme_Object **argv,
                      Scheme_Object *pv, intptr_t *start, intptr_t *end)
{
  intptr_t len, start_pos, end_pos;

  len = SCHEME_PVECTOR_LENGTH(pv);
  start_pos = scheme_extract_index(who, 1, argc, argv, len + 1, 0);
  end_pos = scheme_extract_index(who, 2, argc, argv, len + 1, 0);
  if (start_pos > len) {
    scheme_out_of_range(who, "pvector", "starting ", argv[1], pv, 0, len);
  }
  if ((end_pos < start_pos) || (end_pos > len)) {
    scheme_out_of_range(who, "pvector", "ending ", argv[2], pv, start_pos, len);
  }
  *start = start_pos;
  *end = end_pos;
}

static int
pvector_equal_element_unsafe(Scheme_Object *left, Scheme_Object *right_obj,
                             intptr_t *index, void *cycle_data)
{
  Scheme_Object *right;

  SCHEME_USE_FUEL(1);
  right = pvector_ref_unsafe(right_obj, *index);
  if (!scheme_recur_equal(left, right, cycle_data)) {
    return 0;
  }
  (*index)++;
  return 1;
}

static int
pvector_equal_digit_unsafe(Scheme_Object *digit_obj,
                           Scheme_Object *right_obj,
                           intptr_t *index,
                           void *cycle_data)
{
  int count, i;

  count = SCHEME_PVECTOR_DIGIT_COUNT(digit_obj);
  for (i = 0; i < count; i++) {
    if (!pvector_equal_element_unsafe(SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[i],
                                      right_obj,
                                      index,
                                      cycle_data)) {
      return 0;
    }
  }

  return 1;
}

static int
pvector_equal_node_unsafe(Scheme_Object *node_obj,
                          Scheme_Object *right_obj,
                          intptr_t *index,
                          void *cycle_data)
{
  int arity, level;

  arity = SCHEME_PVECTOR_NODE_ARITY(node_obj);
  level = SCHEME_PVECTOR_NODE_LEVEL(node_obj);

  if (level == 0) {
    if (!pvector_equal_element_unsafe(SCHEME_PVECTOR_NODE_A(node_obj),
                                      right_obj,
                                      index,
                                      cycle_data)) {
      return 0;
    }
    if (!pvector_equal_element_unsafe(SCHEME_PVECTOR_NODE_B(node_obj),
                                      right_obj,
                                      index,
                                      cycle_data)) {
      return 0;
    }
    if (arity == 3) {
      return pvector_equal_element_unsafe(SCHEME_PVECTOR_NODE_C(node_obj),
                                          right_obj,
                                          index,
                                          cycle_data);
    }
  } else {
    if (!pvector_equal_node_unsafe(SCHEME_PVECTOR_NODE_A(node_obj),
                                   right_obj,
                                   index,
                                   cycle_data)) {
      return 0;
    }
    if (!pvector_equal_node_unsafe(SCHEME_PVECTOR_NODE_B(node_obj),
                                   right_obj,
                                   index,
                                   cycle_data)) {
      return 0;
    }
    if (arity == 3) {
      return pvector_equal_node_unsafe(SCHEME_PVECTOR_NODE_C(node_obj),
                                       right_obj,
                                       index,
                                       cycle_data);
    }
  }

  return 1;
}

static int
pvector_equal_left_traverse_unsafe(Scheme_Object *left_obj,
                                   Scheme_Object *right_obj,
                                   void *cycle_data)
{
  intptr_t index;

  if (SCHEME_PVECTOR_SHAPE(left_obj) == SCHEME_PVECTOR_EMPTY) {
    return 1;
  } else if (SCHEME_PVECTOR_SHAPE(left_obj) == SCHEME_PVECTOR_SINGLE) {
    index = 0;
    return pvector_equal_element_unsafe(SCHEME_PVECTOR_A(left_obj),
                                        right_obj,
                                        &index,
                                        cycle_data);
  }

  index = 0;
  if (!pvector_equal_digit_unsafe(SCHEME_PVECTOR_A(left_obj),
                                  right_obj,
                                  &index,
                                  cycle_data)) {
    return 0;
  }
  if (!SCHEME_FALSEP(SCHEME_PVECTOR_B(left_obj))
      && !pvector_equal_node_unsafe(SCHEME_PVECTOR_B(left_obj),
                                    right_obj,
                                    &index,
                                    cycle_data)) {
    return 0;
  }
  return pvector_equal_digit_unsafe(SCHEME_PVECTOR_C(left_obj),
                                    right_obj,
                                    &index,
                                    cycle_data);
}

static uintptr_t
pvector_hash1_element_unsafe(Scheme_Object *elem, uintptr_t hash,
                             void *cycle_data)
{
  intptr_t elem_hash;

  SCHEME_USE_FUEL(1);
  elem_hash = scheme_recur_equal_hash_key(elem, cycle_data);
  return (hash << 5) + hash + elem_hash;
}

static uintptr_t
pvector_hash1_digit_unsafe(Scheme_Object *digit_obj, uintptr_t hash,
                           void *cycle_data)
{
  int count, i;

  count = SCHEME_PVECTOR_DIGIT_COUNT(digit_obj);
  for (i = 0; i < count; i++) {
    hash = pvector_hash1_element_unsafe(SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[i],
                                        hash,
                                        cycle_data);
  }

  return hash;
}

static uintptr_t
pvector_hash1_node_unsafe(Scheme_Object *node_obj, uintptr_t hash,
                          void *cycle_data)
{
  int arity, level;

  arity = SCHEME_PVECTOR_NODE_ARITY(node_obj);
  level = SCHEME_PVECTOR_NODE_LEVEL(node_obj);

  if (level == 0) {
    hash = pvector_hash1_element_unsafe(SCHEME_PVECTOR_NODE_A(node_obj),
                                        hash,
                                        cycle_data);
    hash = pvector_hash1_element_unsafe(SCHEME_PVECTOR_NODE_B(node_obj),
                                        hash,
                                        cycle_data);
    if (arity == 3) {
      hash = pvector_hash1_element_unsafe(SCHEME_PVECTOR_NODE_C(node_obj),
                                          hash,
                                          cycle_data);
    }
  } else {
    hash = pvector_hash1_node_unsafe(SCHEME_PVECTOR_NODE_A(node_obj),
                                     hash,
                                     cycle_data);
    hash = pvector_hash1_node_unsafe(SCHEME_PVECTOR_NODE_B(node_obj),
                                     hash,
                                     cycle_data);
    if (arity == 3) {
      hash = pvector_hash1_node_unsafe(SCHEME_PVECTOR_NODE_C(node_obj),
                                       hash,
                                       cycle_data);
    }
  }

  return hash;
}

static uintptr_t
pvector_hash1_traverse_unsafe(Scheme_Object *pv_obj, uintptr_t hash,
                              void *cycle_data)
{
  if (SCHEME_PVECTOR_SHAPE(pv_obj) == SCHEME_PVECTOR_SINGLE) {
    return pvector_hash1_element_unsafe(SCHEME_PVECTOR_A(pv_obj),
                                        hash,
                                        cycle_data);
  }

  hash = pvector_hash1_digit_unsafe(SCHEME_PVECTOR_A(pv_obj),
                                    hash,
                                    cycle_data);
  if (!SCHEME_FALSEP(SCHEME_PVECTOR_B(pv_obj))) {
    hash = pvector_hash1_node_unsafe(SCHEME_PVECTOR_B(pv_obj),
                                     hash,
                                     cycle_data);
  }
  return pvector_hash1_digit_unsafe(SCHEME_PVECTOR_C(pv_obj),
                                    hash,
                                    cycle_data);
}

static uintptr_t
pvector_hash2_element_unsafe(Scheme_Object *elem, uintptr_t hash,
                             void *cycle_data)
{
  SCHEME_USE_FUEL(1);
  return hash + scheme_recur_equal_hash_key2(elem, cycle_data);
}

static uintptr_t
pvector_hash2_digit_unsafe(Scheme_Object *digit_obj, uintptr_t hash,
                           void *cycle_data)
{
  int count, i;

  count = SCHEME_PVECTOR_DIGIT_COUNT(digit_obj);
  for (i = 0; i < count; i++) {
    hash = pvector_hash2_element_unsafe(SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[i],
                                        hash,
                                        cycle_data);
  }

  return hash;
}

static uintptr_t
pvector_hash2_node_unsafe(Scheme_Object *node_obj, uintptr_t hash,
                          void *cycle_data)
{
  int arity, level;

  arity = SCHEME_PVECTOR_NODE_ARITY(node_obj);
  level = SCHEME_PVECTOR_NODE_LEVEL(node_obj);

  if (level == 0) {
    hash = pvector_hash2_element_unsafe(SCHEME_PVECTOR_NODE_A(node_obj),
                                        hash,
                                        cycle_data);
    hash = pvector_hash2_element_unsafe(SCHEME_PVECTOR_NODE_B(node_obj),
                                        hash,
                                        cycle_data);
    if (arity == 3) {
      hash = pvector_hash2_element_unsafe(SCHEME_PVECTOR_NODE_C(node_obj),
                                          hash,
                                          cycle_data);
    }
  } else {
    hash = pvector_hash2_node_unsafe(SCHEME_PVECTOR_NODE_A(node_obj),
                                     hash,
                                     cycle_data);
    hash = pvector_hash2_node_unsafe(SCHEME_PVECTOR_NODE_B(node_obj),
                                     hash,
                                     cycle_data);
    if (arity == 3) {
      hash = pvector_hash2_node_unsafe(SCHEME_PVECTOR_NODE_C(node_obj),
                                       hash,
                                       cycle_data);
    }
  }

  return hash;
}

static uintptr_t
pvector_hash2_traverse_unsafe(Scheme_Object *pv_obj, uintptr_t hash,
                              void *cycle_data)
{
  if (SCHEME_PVECTOR_SHAPE(pv_obj) == SCHEME_PVECTOR_EMPTY) {
    return hash;
  } else if (SCHEME_PVECTOR_SHAPE(pv_obj) == SCHEME_PVECTOR_SINGLE) {
    return pvector_hash2_element_unsafe(SCHEME_PVECTOR_A(pv_obj),
                                        hash,
                                        cycle_data);
  }

  hash = pvector_hash2_digit_unsafe(SCHEME_PVECTOR_A(pv_obj),
                                    hash,
                                    cycle_data);
  if (!SCHEME_FALSEP(SCHEME_PVECTOR_B(pv_obj))) {
    hash = pvector_hash2_node_unsafe(SCHEME_PVECTOR_B(pv_obj),
                                     hash,
                                     cycle_data);
  }
  return pvector_hash2_digit_unsafe(SCHEME_PVECTOR_C(pv_obj),
                                    hash,
                                    cycle_data);
}

static int
pvector_equal(Scheme_Object *left_obj, Scheme_Object *right_obj,
              void *cycle_data)
{
  intptr_t len;

  len = SCHEME_PVECTOR_LENGTH(left_obj);
  if (len != SCHEME_PVECTOR_LENGTH(right_obj)) {
    return 0;
  }

  return pvector_equal_left_traverse_unsafe(left_obj, right_obj, cycle_data);
}

static intptr_t
pvector_hash1(Scheme_Object *pv_obj, intptr_t base, void *cycle_data)
{
  intptr_t len;
  uintptr_t hash;

  len = SCHEME_PVECTOR_LENGTH(pv_obj);
  if (!len) {
    return base + 1;
  }

  hash = base;
  return pvector_hash1_traverse_unsafe(pv_obj, hash, cycle_data);
}

static intptr_t
pvector_hash2(Scheme_Object *pv_obj, void *cycle_data)
{
  return pvector_hash2_traverse_unsafe(pv_obj, 0, cycle_data);
}

static void
pvector_print(Scheme_Object *pv_obj, int for_display, Scheme_Print_Params *pp)
{
  char buffer[64];

  (void)for_display;
  sprintf(buffer, "#<pvector:%ld>", (long)SCHEME_PVECTOR_LENGTH(pv_obj));
  scheme_print_utf8(pp, buffer, 0, -1);
}

static intptr_t
pvector_fill_vector_digit_unsafe(Scheme_Object *digit_obj,
                                 Scheme_Object *vec,
                                 intptr_t pos)
{
  int count, i;

  count = SCHEME_PVECTOR_DIGIT_COUNT(digit_obj);
  for (i = 0; i < count; i++) {
    SCHEME_VEC_ELS(vec)[pos] = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[i];
    pos++;
  }

  return pos;
}

static intptr_t
pvector_fill_vector_node_unsafe(Scheme_Object *node_obj,
                                Scheme_Object *vec,
                                intptr_t pos)
{
  int arity, level;

  arity = SCHEME_PVECTOR_NODE_ARITY(node_obj);
  level = SCHEME_PVECTOR_NODE_LEVEL(node_obj);

  if (level == 0) {
    SCHEME_VEC_ELS(vec)[pos] = SCHEME_PVECTOR_NODE_A(node_obj);
    pos++;
    SCHEME_VEC_ELS(vec)[pos] = SCHEME_PVECTOR_NODE_B(node_obj);
    pos++;
    if (arity == 3) {
      SCHEME_VEC_ELS(vec)[pos] = SCHEME_PVECTOR_NODE_C(node_obj);
      pos++;
    }
  } else {
    pos = pvector_fill_vector_node_unsafe(SCHEME_PVECTOR_NODE_A(node_obj),
                                          vec,
                                          pos);
    pos = pvector_fill_vector_node_unsafe(SCHEME_PVECTOR_NODE_B(node_obj),
                                          vec,
                                          pos);
    if (arity == 3) {
      pos = pvector_fill_vector_node_unsafe(SCHEME_PVECTOR_NODE_C(node_obj),
                                            vec,
                                            pos);
    }
  }

  return pos;
}

static void
pvector_fill_vector_unsafe(Scheme_Object *pv_obj, Scheme_Object *vec)
{
  intptr_t pos;

  if (SCHEME_PVECTOR_SHAPE(pv_obj) == SCHEME_PVECTOR_EMPTY) {
    return;
  } else if (SCHEME_PVECTOR_SHAPE(pv_obj) == SCHEME_PVECTOR_SINGLE) {
    SCHEME_VEC_ELS(vec)[0] = SCHEME_PVECTOR_A(pv_obj);
    return;
  }

  pos = pvector_fill_vector_digit_unsafe(SCHEME_PVECTOR_A(pv_obj), vec, 0);
  if (!SCHEME_FALSEP(SCHEME_PVECTOR_B(pv_obj))) {
    pos = pvector_fill_vector_node_unsafe(SCHEME_PVECTOR_B(pv_obj), vec, pos);
  }
  (void)pvector_fill_vector_digit_unsafe(SCHEME_PVECTOR_C(pv_obj), vec, pos);
}

static Scheme_Object *
pvector_to_vector_unsafe(Scheme_Object *pv_obj)
{
  Scheme_Object *vec, *prefix, *middle, *suffix;
  intptr_t len;
  int pos, prefix_len, suffix_len, middle_arity;

  len = SCHEME_PVECTOR_LENGTH(pv_obj);
  vec = (Scheme_Object *)scheme_make_vector(len, NULL);
  if (len == 0) {
    return vec;
  } else if (len == 1) {
    SCHEME_VEC_ELS(vec)[0] = SCHEME_PVECTOR_A(pv_obj);
    return vec;
  } else if (len <= 4) {
    prefix = SCHEME_PVECTOR_A(pv_obj);
    middle = SCHEME_PVECTOR_B(pv_obj);
    suffix = SCHEME_PVECTOR_C(pv_obj);
    prefix_len = SCHEME_PVECTOR_PREFIX_LEN(pv_obj);
    suffix_len = SCHEME_PVECTOR_SUFFIX_LEN(pv_obj);
    if (!SCHEME_FALSEP(middle)
        && (SCHEME_PVECTOR_NODE_LEVEL(middle) != 0)) {
      pvector_fill_vector_unsafe(pv_obj, vec);
      return vec;
    }

    pos = 0;
    if (prefix_len > 0) SCHEME_VEC_ELS(vec)[pos++] = SCHEME_PVECTOR_DIGIT_ELS(prefix)[0];
    if (prefix_len > 1) SCHEME_VEC_ELS(vec)[pos++] = SCHEME_PVECTOR_DIGIT_ELS(prefix)[1];
    if (prefix_len > 2) SCHEME_VEC_ELS(vec)[pos++] = SCHEME_PVECTOR_DIGIT_ELS(prefix)[2];
    if (prefix_len > 3) SCHEME_VEC_ELS(vec)[pos++] = SCHEME_PVECTOR_DIGIT_ELS(prefix)[3];
    if (!SCHEME_FALSEP(middle)) {
      middle_arity = SCHEME_PVECTOR_NODE_ARITY(middle);
      SCHEME_VEC_ELS(vec)[pos++] = SCHEME_PVECTOR_NODE_A(middle);
      SCHEME_VEC_ELS(vec)[pos++] = SCHEME_PVECTOR_NODE_B(middle);
      if (middle_arity == 3) {
        SCHEME_VEC_ELS(vec)[pos++] = SCHEME_PVECTOR_NODE_C(middle);
      }
    }
    if (suffix_len > 0) SCHEME_VEC_ELS(vec)[pos++] = SCHEME_PVECTOR_DIGIT_ELS(suffix)[0];
    if (suffix_len > 1) SCHEME_VEC_ELS(vec)[pos++] = SCHEME_PVECTOR_DIGIT_ELS(suffix)[1];
    if (suffix_len > 2) SCHEME_VEC_ELS(vec)[pos++] = SCHEME_PVECTOR_DIGIT_ELS(suffix)[2];
    if (suffix_len > 3) SCHEME_VEC_ELS(vec)[pos++] = SCHEME_PVECTOR_DIGIT_ELS(suffix)[3];
    return vec;
  }

  pvector_fill_vector_unsafe(pv_obj, vec);
  return vec;
}

static Scheme_Object *
pvector_digit_to_list_reverse_unsafe(Scheme_Object *digit_obj,
                                     Scheme_Object *tail)
{
  int i;

  for (i = SCHEME_PVECTOR_DIGIT_COUNT(digit_obj) - 1; i >= 0; i--) {
    Scheme_Object *elem;

    elem = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[i];
    tail = scheme_make_pair(elem, tail);
  }

  return tail;
}

static Scheme_Object *
pvector_node_to_list_reverse_unsafe(Scheme_Object *node_obj,
                                    Scheme_Object *tail)
{
  int arity, level;

  arity = SCHEME_PVECTOR_NODE_ARITY(node_obj);
  level = SCHEME_PVECTOR_NODE_LEVEL(node_obj);

  if (level == 0) {
    if (arity == 3) {
      tail = scheme_make_pair(SCHEME_PVECTOR_NODE_C(node_obj), tail);
    }
    tail = scheme_make_pair(SCHEME_PVECTOR_NODE_B(node_obj), tail);
    tail = scheme_make_pair(SCHEME_PVECTOR_NODE_A(node_obj), tail);
  } else {
    if (arity == 3) {
      tail = pvector_node_to_list_reverse_unsafe(SCHEME_PVECTOR_NODE_C(node_obj),
                                                 tail);
    }
    tail = pvector_node_to_list_reverse_unsafe(SCHEME_PVECTOR_NODE_B(node_obj),
                                               tail);
    tail = pvector_node_to_list_reverse_unsafe(SCHEME_PVECTOR_NODE_A(node_obj),
                                               tail);
  }

  return tail;
}

static Scheme_Object *
pvector_to_list_unsafe(Scheme_Object *pv_obj)
{
  Scheme_Object *tail, *prefix, *middle, *suffix, *elem;
  Scheme_Object *e0 = NULL, *e1 = NULL, *e2 = NULL, *e3 = NULL;
  intptr_t len;
  int pos, prefix_len, suffix_len, middle_arity;

  len = SCHEME_PVECTOR_LENGTH(pv_obj);
  if (len == 0) {
    return scheme_null;
  } else if (len == 1) {
    return scheme_make_pair(SCHEME_PVECTOR_A(pv_obj), scheme_null);
  } else if (len <= 4) {
    prefix = SCHEME_PVECTOR_A(pv_obj);
    middle = SCHEME_PVECTOR_B(pv_obj);
    suffix = SCHEME_PVECTOR_C(pv_obj);
    prefix_len = SCHEME_PVECTOR_PREFIX_LEN(pv_obj);
    suffix_len = SCHEME_PVECTOR_SUFFIX_LEN(pv_obj);
    if (!SCHEME_FALSEP(middle)
        && (SCHEME_PVECTOR_NODE_LEVEL(middle) != 0)) {
      tail = scheme_null;
      tail = pvector_digit_to_list_reverse_unsafe(SCHEME_PVECTOR_C(pv_obj), tail);
      tail = pvector_node_to_list_reverse_unsafe(middle, tail);
      return pvector_digit_to_list_reverse_unsafe(SCHEME_PVECTOR_A(pv_obj), tail);
    }

    pos = 0;
    if (prefix_len > 0) e0 = SCHEME_PVECTOR_DIGIT_ELS(prefix)[0], pos++;
    if (prefix_len > 1) e1 = SCHEME_PVECTOR_DIGIT_ELS(prefix)[1], pos++;
    if (prefix_len > 2) e2 = SCHEME_PVECTOR_DIGIT_ELS(prefix)[2], pos++;
    if (prefix_len > 3) e3 = SCHEME_PVECTOR_DIGIT_ELS(prefix)[3], pos++;
    if (!SCHEME_FALSEP(middle)) {
      middle_arity = SCHEME_PVECTOR_NODE_ARITY(middle);
      elem = SCHEME_PVECTOR_NODE_A(middle);
      if (pos == 0) e0 = elem;
      else if (pos == 1) e1 = elem;
      else if (pos == 2) e2 = elem;
      else e3 = elem;
      pos++;
      elem = SCHEME_PVECTOR_NODE_B(middle);
      if (pos == 0) e0 = elem;
      else if (pos == 1) e1 = elem;
      else if (pos == 2) e2 = elem;
      else e3 = elem;
      pos++;
      if (middle_arity == 3) {
        elem = SCHEME_PVECTOR_NODE_C(middle);
        if (pos == 0) e0 = elem;
        else if (pos == 1) e1 = elem;
        else if (pos == 2) e2 = elem;
        else e3 = elem;
        pos++;
      }
    }
    if (suffix_len > 0) {
      if (pos == 0) e0 = SCHEME_PVECTOR_DIGIT_ELS(suffix)[0];
      else if (pos == 1) e1 = SCHEME_PVECTOR_DIGIT_ELS(suffix)[0];
      else if (pos == 2) e2 = SCHEME_PVECTOR_DIGIT_ELS(suffix)[0];
      else e3 = SCHEME_PVECTOR_DIGIT_ELS(suffix)[0];
      pos++;
    }
    if (suffix_len > 1) {
      if (pos == 0) e0 = SCHEME_PVECTOR_DIGIT_ELS(suffix)[1];
      else if (pos == 1) e1 = SCHEME_PVECTOR_DIGIT_ELS(suffix)[1];
      else if (pos == 2) e2 = SCHEME_PVECTOR_DIGIT_ELS(suffix)[1];
      else e3 = SCHEME_PVECTOR_DIGIT_ELS(suffix)[1];
      pos++;
    }
    if (suffix_len > 2) {
      if (pos == 0) e0 = SCHEME_PVECTOR_DIGIT_ELS(suffix)[2];
      else if (pos == 1) e1 = SCHEME_PVECTOR_DIGIT_ELS(suffix)[2];
      else if (pos == 2) e2 = SCHEME_PVECTOR_DIGIT_ELS(suffix)[2];
      else e3 = SCHEME_PVECTOR_DIGIT_ELS(suffix)[2];
      pos++;
    }
    if (suffix_len > 3) {
      if (pos == 0) e0 = SCHEME_PVECTOR_DIGIT_ELS(suffix)[3];
      else if (pos == 1) e1 = SCHEME_PVECTOR_DIGIT_ELS(suffix)[3];
      else if (pos == 2) e2 = SCHEME_PVECTOR_DIGIT_ELS(suffix)[3];
      else e3 = SCHEME_PVECTOR_DIGIT_ELS(suffix)[3];
    }

    if (len == 2) {
      return scheme_make_pair(e0, scheme_make_pair(e1, scheme_null));
    } else if (len == 3) {
      return scheme_make_pair(e0, scheme_make_pair(e1, scheme_make_pair(e2, scheme_null)));
    } else {
      return scheme_make_pair(e0, scheme_make_pair(e1, scheme_make_pair(e2, scheme_make_pair(e3, scheme_null))));
    }
  }

  tail = scheme_null;
  tail = pvector_digit_to_list_reverse_unsafe(SCHEME_PVECTOR_C(pv_obj), tail);
  if (!SCHEME_FALSEP(SCHEME_PVECTOR_B(pv_obj))) {
    tail = pvector_node_to_list_reverse_unsafe(SCHEME_PVECTOR_B(pv_obj), tail);
  }
  return pvector_digit_to_list_reverse_unsafe(SCHEME_PVECTOR_A(pv_obj), tail);
}

static Scheme_Object *
checked_vector_arg(const char *who, int argc, Scheme_Object **argv)
{
  Scheme_Object *vec = argv[0];

  if (SCHEME_NP_CHAPERONEP(vec)) {
    vec = SCHEME_CHAPERONE_VAL(vec);
  }

  if (!SCHEME_VECTORP(vec)) {
    scheme_wrong_contract(who, "vector?", 0, argc, argv);
    return NULL;
  }

  return vec;
}

static void
hash_set_sym(Scheme_Hash_Table *ht, const char *key, Scheme_Object *val)
{
  scheme_hash_set(ht, scheme_intern_symbol(key), val);
}

static void
count_nodes(Scheme_Object *node_obj, intptr_t *_nodes, intptr_t *_node2, intptr_t *_node3)
{
  Scheme_PVector_Node *node;

  if (SCHEME_FALSEP(node_obj)) {
    return;
  }

  node = (Scheme_PVector_Node *)node_obj;
  (*_nodes)++;
  if (node->arity == 2) {
    (*_node2)++;
  } else {
    (*_node3)++;
  }

  if (node->level > 0) {
    count_nodes(node->a, _nodes, _node2, _node3);
    count_nodes(node->b, _nodes, _node2, _node3);
    if (node->arity == 3) {
      count_nodes(node->c, _nodes, _node2, _node3);
    }
  }
}

static Scheme_Object *
core_pvector_p(int argc, Scheme_Object *argv[])
{
  return (SCHEME_PVECTORP(argv[0]) ? scheme_true : scheme_false);
}

static Scheme_Object *
core_pvector_empty_prim(int argc, Scheme_Object *argv[])
{
  return core_pvector_empty;
}

static Scheme_Object *
core_pvector_empty_p(int argc, Scheme_Object *argv[])
{
  return (SAME_OBJ(argv[0], core_pvector_empty) ? scheme_true : scheme_false);
}

static Scheme_Object *
core_pvector_length_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv;

  pv = checked_pvector("core-pvector-length", argc, argv);
  return scheme_make_integer(SCHEME_PVECTOR_LENGTH(pv));
}

Scheme_Object *
scheme_pvector_length(Scheme_Object *v)
{
  Scheme_Object *pv;

  pv = checked_pvector_value("core-pvector-length", v);
  return scheme_make_integer(SCHEME_PVECTOR_LENGTH(pv));
}

static Scheme_Object *
core_pvector_shape_stats(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv_obj, *middle;
  Scheme_PVector *pv;
  Scheme_Hash_Table *ht;
  intptr_t nodes = 0, node2 = 0, node3 = 0, middle_measure = 0, depth = 0;

  pv_obj = checked_pvector("core-pvector-shape-stats", argc, argv);
  pv = (Scheme_PVector *)pv_obj;
  ht = scheme_make_hash_table_equal();

  hash_set_sym(ht, "backend", scheme_intern_symbol("bc-native"));
  hash_set_sym(ht, "length", scheme_make_integer(pv->length));
  hash_set_sym(ht, "chunked-tree?", scheme_false);
  hash_set_sym(ht, "chunk-index-vectors", scheme_make_integer(0));
  hash_set_sym(ht, "chunk-index-slots", scheme_make_integer(0));
  hash_set_sym(ht, "ref-cache?", scheme_false);
  hash_set_sym(ht, "payload-vectors", scheme_make_integer(0));

  if (pv->shape == SCHEME_PVECTOR_EMPTY) {
    hash_set_sym(ht, "representation", scheme_intern_symbol("empty"));
    hash_set_sym(ht, "digit-vectors", scheme_make_integer(0));
    hash_set_sym(ht, "prefix-length", scheme_make_integer(0));
    hash_set_sym(ht, "suffix-length", scheme_make_integer(0));
  } else if (pv->shape == SCHEME_PVECTOR_SINGLE) {
    hash_set_sym(ht, "representation", scheme_intern_symbol("single"));
    hash_set_sym(ht, "digit-vectors", scheme_make_integer(0));
    hash_set_sym(ht, "prefix-length", scheme_make_integer(0));
    hash_set_sym(ht, "suffix-length", scheme_make_integer(0));
  } else {
    middle = pv->b;
    hash_set_sym(ht, "representation", scheme_intern_symbol("large-finger"));
    hash_set_sym(ht, "digit-vectors", scheme_make_integer(2));
    hash_set_sym(ht, "prefix-length", scheme_make_integer(pv->prefix_len));
    hash_set_sym(ht, "suffix-length", scheme_make_integer(pv->suffix_len));
    if (!SCHEME_FALSEP(middle)) {
      middle_measure = SCHEME_PVECTOR_NODE_MEASURE(middle);
      depth = SCHEME_PVECTOR_NODE_LEVEL(middle) + 1;
      count_nodes(middle, &nodes, &node2, &node3);
    }
  }

  hash_set_sym(ht, "middle-measure", scheme_make_integer(middle_measure));
  hash_set_sym(ht, "finger-depth", scheme_make_integer(depth));
  hash_set_sym(ht, "finger-nodes", scheme_make_integer(nodes));
  hash_set_sym(ht, "node2", scheme_make_integer(node2));
  hash_set_sym(ht, "node3", scheme_make_integer(node3));

  return (Scheme_Object *)ht;
}

static Scheme_Object *
core_vector_to_pvector(int argc, Scheme_Object *argv[])
{
  Scheme_Object *vec;

  vec = checked_vector_arg("core-vector->pvector", argc, argv);
  return pvector_from_vector(vec);
}

static Scheme_Object *
core_immutable_vector_to_pvector(int argc, Scheme_Object *argv[])
{
  Scheme_Object *vec;

  vec = checked_vector_arg("core-immutable-vector->pvector", argc, argv);
  return pvector_from_vector(vec);
}

static Scheme_Object *
core_fresh_vector_to_pvector(int argc, Scheme_Object *argv[])
{
  Scheme_Object *vec;

  vec = checked_vector_arg("core-fresh-vector->pvector", argc, argv);
  return pvector_from_vector(vec);
}

static Scheme_Object *
core_list_to_pvector(int argc, Scheme_Object *argv[])
{
  return pvector_from_list(argv[0]);
}

static Scheme_Object *
core_make_single_pvector(int argc, Scheme_Object *argv[])
{
  return make_single_pvector(argv[0]);
}

static Scheme_Object *
core_make_deep2_pvector(int argc, Scheme_Object *argv[])
{
  return pvector_from_args(argc, argv);
}

static Scheme_Object *
core_make_deep3_pvector(int argc, Scheme_Object *argv[])
{
  return pvector_from_args(argc, argv);
}

static Scheme_Object *
core_make_deep4_pvector(int argc, Scheme_Object *argv[])
{
  return pvector_from_args(argc, argv);
}

static Scheme_Object *
core_make_pvector(int argc, Scheme_Object *argv[])
{
  intptr_t len;
  Scheme_Object *fill;

  len = scheme_extract_index("core-make-pvector", 0, argc, argv, -1, 0);
  fill = argv[1];
  return pvector_from_constant(len, fill);
}

static Scheme_Object *
core_pvector_to_vector(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv;

  pv = checked_pvector("core-pvector->vector", argc, argv);
  return pvector_to_vector_unsafe(pv);
}

static Scheme_Object *
core_pvector_to_list(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv;

  pv = checked_pvector("core-pvector->list", argc, argv);
  return pvector_to_list_unsafe(pv);
}

static Scheme_Object *
core_pvector_ref_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv;
  intptr_t index;
  int too_large;

  index = checked_pvector_index_contract("core-pvector-ref", argc, argv, 1, &too_large);
  pv = checked_pvector("core-pvector-ref", argc, argv);
  if (too_large || (index >= SCHEME_PVECTOR_LENGTH(pv))) {
    scheme_out_of_range("core-pvector-ref", "pvector", "", argv[1], pv,
                        0, SCHEME_PVECTOR_LENGTH(pv) - 1);
    return NULL;
  }
  return pvector_ref_unsafe(pv, index);
}

Scheme_Object *
scheme_pvector_ref(Scheme_Object *pv, Scheme_Object *index)
{
  Scheme_Object *argv[2];
  intptr_t i;
  int too_large;

  argv[0] = pv;
  argv[1] = index;
  i = checked_pvector_index_contract("core-pvector-ref", 2, argv, 1, &too_large);
  pv = checked_pvector_value("core-pvector-ref", pv);
  if (too_large || (i >= SCHEME_PVECTOR_LENGTH(pv))) {
    scheme_out_of_range("core-pvector-ref", "pvector", "", index, pv,
                        0, SCHEME_PVECTOR_LENGTH(pv) - 1);
    return NULL;
  }
  return pvector_ref_unsafe(pv, i);
}

static Scheme_Object *
core_unsafe_pvector_length_prim(int argc, Scheme_Object *argv[])
{
  return scheme_make_integer(SCHEME_PVECTOR_LENGTH(argv[0]));
}

static Scheme_Object *
core_unsafe_pvector_ref_prim(int argc, Scheme_Object *argv[])
{
  return pvector_ref_unsafe(argv[0], SCHEME_INT_VAL(argv[1]));
}

static Scheme_Object *
core_unsafe_pvector_view_left_prim(int argc, Scheme_Object *argv[])
{
  return pvector_view_left_unsafe(argv[0]);
}

static Scheme_Object *
core_unsafe_pvector_view_right_prim(int argc, Scheme_Object *argv[])
{
  return pvector_view_right_unsafe(argv[0]);
}

static Scheme_Object *
core_pvector_set_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv_obj, *value, *prefix, *middle, *suffix;
  Scheme_PVector *pv;
  intptr_t index, suffix_start;
  int too_large;

  index = checked_pvector_index_contract("core-pvector-set", argc, argv, 1, &too_large);
  pv_obj = checked_pvector("core-pvector-set", argc, argv);
  index = checked_pvector_index_after_contract("core-pvector-set", argc, argv, 1,
                                               pv_obj, index, too_large);
  value = argv[2];

  pv = (Scheme_PVector *)pv_obj;
  if (pv->shape == SCHEME_PVECTOR_SINGLE) {
    if (SAME_OBJ(pv->a, value)) {
      return pv_obj;
    }
    return make_single_pvector(value);
  }

  if (pv->shape != SCHEME_PVECTOR_DEEP) {
    scheme_signal_error("internal error: pvector set reached empty pvector");
    return NULL;
  }

  suffix_start = pv->length - pv->suffix_len;
  if (index < pv->prefix_len) {
    if (SAME_OBJ(SCHEME_PVECTOR_DIGIT_ELS(pv->a)[index], value)) {
      return pv_obj;
    }
    prefix = make_digit_with_replaced(pv->a, (int)index, value);
    return make_deep_pvector(pv->length, prefix, pv->b, pv->c,
                             pv->prefix_len, pv->suffix_len);
  } else if (index >= suffix_start) {
    if (SAME_OBJ(SCHEME_PVECTOR_DIGIT_ELS(pv->c)[index - suffix_start], value)) {
      return pv_obj;
    }
    suffix = make_digit_with_replaced(pv->c, (int)(index - suffix_start), value);
    return make_deep_pvector(pv->length, pv->a, pv->b, suffix,
                             pv->prefix_len, pv->suffix_len);
  } else {
    middle = node_set(pv->b, index - pv->prefix_len, value);
    if (SAME_OBJ(middle, pv->b)) {
      return pv_obj;
    }
    return make_deep_pvector(pv->length, pv->a, middle, pv->c,
                             pv->prefix_len, pv->suffix_len);
  }
}

static Scheme_Object *
pvector_cons_left_unsafe(Scheme_Object *pv_obj, Scheme_Object *value)
{
  Scheme_Object *prefix, *middle, *suffix, *old_prefix_obj;
  Scheme_Object *p0, *p1, *p2, *p3;
  intptr_t len;
  int old_prefix_count, shape, suffix_len;

  shape = SCHEME_PVECTOR_SHAPE(pv_obj);
  if (shape == SCHEME_PVECTOR_EMPTY) {
    return make_single_pvector(value);
  } else if (shape == SCHEME_PVECTOR_SINGLE) {
    p0 = SCHEME_PVECTOR_A(pv_obj);
    prefix = make_digit_from_fields(1, value, NULL, NULL, NULL);
    return make_deep_pvector(2,
                             prefix,
                             scheme_false,
                             make_digit_from_fields(1, p0, NULL, NULL, NULL),
                             1, 1);
  }

  len = SCHEME_PVECTOR_LENGTH(pv_obj);
  old_prefix_obj = SCHEME_PVECTOR_A(pv_obj);
  middle = SCHEME_PVECTOR_B(pv_obj);
  suffix = SCHEME_PVECTOR_C(pv_obj);
  suffix_len = SCHEME_PVECTOR_SUFFIX_LEN(pv_obj);
  old_prefix_count = SCHEME_PVECTOR_DIGIT_COUNT(old_prefix_obj);
  p0 = SCHEME_PVECTOR_DIGIT_ELS(old_prefix_obj)[0];
  p1 = SCHEME_PVECTOR_DIGIT_ELS(old_prefix_obj)[1];
  p2 = SCHEME_PVECTOR_DIGIT_ELS(old_prefix_obj)[2];
  p3 = SCHEME_PVECTOR_DIGIT_ELS(old_prefix_obj)[3];

  if (old_prefix_count < 4) {
    prefix = make_digit_with_prepended(old_prefix_obj, value);
    return make_deep_pvector(len + 1, prefix, middle, suffix,
                             old_prefix_count + 1, suffix_len);
  } else {
    prefix = make_digit_from_fields(2, value, p0, NULL, NULL);
    middle = node_tree_prepend3(middle, p1, p2, p3);
    return make_deep_pvector(len + 1, prefix, middle, suffix,
                             2, suffix_len);
  }
}

static Scheme_Object *
pvector_cons_right_unsafe(Scheme_Object *pv_obj, Scheme_Object *value)
{
  Scheme_Object *prefix, *suffix, *middle, *old_suffix_obj;
  Scheme_Object *s0, *s1, *s2, *s3;
  intptr_t len;
  int old_suffix_count, prefix_len, shape;

  shape = SCHEME_PVECTOR_SHAPE(pv_obj);
  if (shape == SCHEME_PVECTOR_EMPTY) {
    return make_single_pvector(value);
  } else if (shape == SCHEME_PVECTOR_SINGLE) {
    s0 = SCHEME_PVECTOR_A(pv_obj);
    suffix = make_digit_from_fields(1, value, NULL, NULL, NULL);
    return make_deep_pvector(2,
                             make_digit_from_fields(1, s0, NULL, NULL, NULL),
                             scheme_false,
                             suffix,
                             1, 1);
  }

  len = SCHEME_PVECTOR_LENGTH(pv_obj);
  prefix = SCHEME_PVECTOR_A(pv_obj);
  middle = SCHEME_PVECTOR_B(pv_obj);
  old_suffix_obj = SCHEME_PVECTOR_C(pv_obj);
  prefix_len = SCHEME_PVECTOR_PREFIX_LEN(pv_obj);
  old_suffix_count = SCHEME_PVECTOR_DIGIT_COUNT(old_suffix_obj);
  s0 = SCHEME_PVECTOR_DIGIT_ELS(old_suffix_obj)[0];
  s1 = SCHEME_PVECTOR_DIGIT_ELS(old_suffix_obj)[1];
  s2 = SCHEME_PVECTOR_DIGIT_ELS(old_suffix_obj)[2];
  s3 = SCHEME_PVECTOR_DIGIT_ELS(old_suffix_obj)[3];

  if (old_suffix_count < 4) {
    suffix = make_digit_with_appended(old_suffix_obj, value);
    return make_deep_pvector(len + 1, prefix, middle, suffix,
                             prefix_len, old_suffix_count + 1);
  } else {
    middle = node_tree_append3(middle, s0, s1, s2);
    suffix = make_digit_from_fields(2, s3, value, NULL, NULL);
    return make_deep_pvector(len + 1, prefix, middle, suffix,
                             prefix_len, 2);
  }
}

static Scheme_Object *
pvector_from_small_fields(int count,
                          Scheme_Object *a, Scheme_Object *b,
                          Scheme_Object *c, Scheme_Object *d)
{
  if (count == 0) {
    return core_pvector_empty;
  } else if (count == 1) {
    return make_single_pvector(a);
  } else if (count == 2) {
    return make_deep_pvector(2,
                             make_digit_from_fields(1, a, NULL, NULL, NULL),
                             scheme_false,
                             make_digit_from_fields(1, b, NULL, NULL, NULL),
                             1, 1);
  } else if (count == 3) {
    return make_deep_pvector(3,
                             make_digit_from_fields(1, a, NULL, NULL, NULL),
                             scheme_false,
                             make_digit_from_fields(2, b, c, NULL, NULL),
                             1, 2);
  } else if (count == 4) {
    return make_deep_pvector(4,
                             make_digit_from_fields(2, a, b, NULL, NULL),
                             scheme_false,
                             make_digit_from_fields(2, c, d, NULL, NULL),
                             2, 2);
  } else {
    scheme_signal_error("internal error: small pvector arity is not 0..4");
    return NULL;
  }
}

static Scheme_Object *
pvector_digit_range_unsafe(Scheme_Object *digit_obj, int start, int end)
{
  Scheme_Object *a = NULL, *b = NULL, *c = NULL, *d = NULL;
  int count, i, pos;

  count = end - start;
  pos = 0;
  for (i = start; i < end; i++) {
    if (pos == 0) a = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[i];
    else if (pos == 1) b = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[i];
    else if (pos == 2) c = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[i];
    else d = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[i];
    pos++;
  }

  return pvector_from_small_fields(count, a, b, c, d);
}

static Scheme_Object *
make_digit_slice_unsafe(Scheme_Object *digit_obj, int start, int end)
{
  Scheme_Object *a = NULL, *b = NULL, *c = NULL, *d = NULL;
  int count, i, pos;

  count = end - start;
  pos = 0;
  for (i = start; i < end; i++) {
    if (pos == 0) a = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[i];
    else if (pos == 1) b = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[i];
    else if (pos == 2) c = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[i];
    else d = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[i];
    pos++;
  }

  return make_digit_from_fields(count, a, b, c, d);
}

static Scheme_Object *
make_digit_without_index_unsafe(Scheme_Object *digit_obj, int index)
{
  Scheme_Object *a = NULL, *b = NULL, *c = NULL, *d = NULL;
  int count, i, pos;

  count = SCHEME_PVECTOR_DIGIT_COUNT(digit_obj);
  if ((index < 0) || (index >= count) || (count <= 1)) {
    scheme_signal_error("internal error: pvector digit delete index is out of range");
    return NULL;
  }

  pos = 0;
  for (i = 0; i < count; i++) {
    if (i != index) {
      if (pos == 0) a = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[i];
      else if (pos == 1) b = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[i];
      else if (pos == 2) c = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[i];
      else d = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[i];
      pos++;
    }
  }

  return make_digit_from_fields(count - 1, a, b, c, d);
}

static Scheme_Object *
make_digit_with_insert_unsafe(Scheme_Object *digit_obj,
                              int index,
                              Scheme_Object *value)
{
  Scheme_Object *a = NULL, *b = NULL, *c = NULL, *d = NULL;
  Scheme_Object *elem;
  int count, i, old_pos;

  count = SCHEME_PVECTOR_DIGIT_COUNT(digit_obj);
  if ((index < 0) || (index > count) || (count >= 4)) {
    scheme_signal_error("internal error: pvector digit insert index is out of range");
    return NULL;
  }

  old_pos = 0;
  for (i = 0; i <= count; i++) {
    if (i == index) {
      elem = value;
    } else {
      elem = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[old_pos];
      old_pos++;
    }

    if (i == 0) a = elem;
    else if (i == 1) b = elem;
    else if (i == 2) c = elem;
    else d = elem;
  }

  return make_digit_from_fields(count + 1, a, b, c, d);
}

static Scheme_Object *
pvector_leaf_node_range_unsafe(Scheme_Object *node_obj, intptr_t start, intptr_t end)
{
  Scheme_Object *a = NULL, *b = NULL, *c = NULL;
  intptr_t i, count, pos;

  count = end - start;
  pos = 0;
  for (i = start; i < end; i++) {
    if (pos == 0) {
      a = (i == 0) ? SCHEME_PVECTOR_NODE_A(node_obj) : ((i == 1) ? SCHEME_PVECTOR_NODE_B(node_obj) : SCHEME_PVECTOR_NODE_C(node_obj));
    } else if (pos == 1) {
      b = (i == 0) ? SCHEME_PVECTOR_NODE_A(node_obj) : ((i == 1) ? SCHEME_PVECTOR_NODE_B(node_obj) : SCHEME_PVECTOR_NODE_C(node_obj));
    } else {
      c = (i == 0) ? SCHEME_PVECTOR_NODE_A(node_obj) : ((i == 1) ? SCHEME_PVECTOR_NODE_B(node_obj) : SCHEME_PVECTOR_NODE_C(node_obj));
    }
    pos++;
  }

  return pvector_from_small_fields((int)count, a, b, c, NULL);
}

static Scheme_Object *
pvector_from_node_tree_unsafe(Scheme_Object *node_obj)
{
  Scheme_Object *left_leaf = NULL, *right_leaf = NULL, *middle = NULL, *rest = NULL;
  Scheme_Object *prefix, *suffix;
  Scheme_PVector_Node *node;
  intptr_t len;
  int left_arity, right_arity, level;

  if (SCHEME_FALSEP(node_obj)) {
    return core_pvector_empty;
  }

  len = SCHEME_PVECTOR_NODE_MEASURE(node_obj);
  level = SCHEME_PVECTOR_NODE_LEVEL(node_obj);
  if (level == 0) {
    return pvector_leaf_node_range_unsafe(node_obj, 0, len);
  } else if (level == 1) {
    node = (Scheme_PVector_Node *)node_obj;
    left_leaf = node->a;
    if (node->arity == 2) {
      middle = scheme_false;
      right_leaf = node->b;
    } else {
      middle = node->b;
      right_leaf = node->c;
    }
    left_arity = SCHEME_PVECTOR_NODE_ARITY(left_leaf);
    right_arity = SCHEME_PVECTOR_NODE_ARITY(right_leaf);
    prefix = make_digit_from_leaf_node(left_leaf);
    suffix = make_digit_from_leaf_node(right_leaf);
    return make_deep_pvector(len, prefix, middle, suffix,
                             left_arity, right_arity);
  }

  node_tree_pop_left_leaf(node_obj, &left_leaf, &rest);
  if (SCHEME_FALSEP(rest)) {
    return pvector_from_node_tree_unsafe(left_leaf);
  }

  node_tree_pop_right_leaf(rest, &right_leaf, &middle);
  left_arity = SCHEME_PVECTOR_NODE_ARITY(left_leaf);
  right_arity = SCHEME_PVECTOR_NODE_ARITY(right_leaf);
  prefix = make_digit_from_leaf_node(left_leaf);
  suffix = make_digit_from_leaf_node(right_leaf);

  return make_deep_pvector(len, prefix, middle, suffix,
                           left_arity, right_arity);
}

static Scheme_Object *
pvector_from_prefix_middle_digit_unsafe(Scheme_Object *prefix,
                                        int prefix_len,
                                        Scheme_Object *middle)
{
  Scheme_Object *right_leaf = NULL, *middle_rest = NULL, *suffix;
  intptr_t len;
  int suffix_len;

  if (SCHEME_FALSEP(middle)) {
    return pvector_digit_range_unsafe(prefix, 0, prefix_len);
  }

  len = prefix_len + SCHEME_PVECTOR_NODE_MEASURE(middle);
  node_tree_pop_right_leaf(middle, &right_leaf, &middle_rest);
  suffix_len = SCHEME_PVECTOR_NODE_ARITY(right_leaf);
  suffix = make_digit_from_leaf_node(right_leaf);
  return make_deep_pvector(len, prefix, middle_rest, suffix,
                           prefix_len, suffix_len);
}

static Scheme_Object *
pvector_from_middle_suffix_digit_unsafe(Scheme_Object *middle,
                                        Scheme_Object *suffix,
                                        int suffix_len)
{
  Scheme_Object *left_leaf = NULL, *middle_rest = NULL, *prefix;
  intptr_t len;
  int prefix_len;

  if (SCHEME_FALSEP(middle)) {
    return pvector_digit_range_unsafe(suffix, 0, suffix_len);
  }

  len = SCHEME_PVECTOR_NODE_MEASURE(middle) + suffix_len;
  node_tree_pop_left_leaf(middle, &left_leaf, &middle_rest);
  prefix_len = SCHEME_PVECTOR_NODE_ARITY(left_leaf);
  prefix = make_digit_from_leaf_node(left_leaf);
  return make_deep_pvector(len, prefix, middle_rest, suffix,
                           prefix_len, suffix_len);
}

static Scheme_Object *
pvector_prepend_digit_unsafe(Scheme_Object *digit_obj,
                             int digit_len,
                             Scheme_Object *right_obj)
{
  Scheme_Object *left_prefix, *left_suffix, *middle;
  Scheme_Object *right_prefix, *right_middle, *right_suffix;
  Scheme_Object *right_value;
  Scheme_Object *e0, *e1, *e2, *e3;
  intptr_t len;
  int left_prefix_len, right_shape, right_suffix_len;

  if (digit_len <= 0) {
    return right_obj;
  } else if (SCHEME_PVECTOR_SHAPE(right_obj) == SCHEME_PVECTOR_EMPTY) {
    return pvector_digit_range_unsafe(digit_obj, 0, digit_len);
  }

  e0 = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[0];
  if (digit_len == 1) {
    return pvector_cons_left_unsafe(right_obj, e0);
  }

  e1 = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[1];
  right_shape = SCHEME_PVECTOR_SHAPE(right_obj);
  if (right_shape == SCHEME_PVECTOR_SINGLE) {
    right_value = SCHEME_PVECTOR_A(right_obj);
    if (digit_len == 2) {
      return pvector_from_small_fields(3, e0, e1, right_value, NULL);
    }

    e2 = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[2];
    if (digit_len == 3) {
      return pvector_from_small_fields(4, e0, e1, e2, right_value);
    }

    e3 = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[3];
    if (digit_len == 4) {
      return make_deep_pvector(5,
                               make_digit_from_fields(2, e0, e1, NULL, NULL),
                               scheme_false,
                               make_digit_from_fields(3, e2, e3, right_value, NULL),
                               2, 3);
    }

    scheme_signal_error("internal error: pvector prepend digit length is not 1..4");
    return NULL;
  }

  if (right_shape != SCHEME_PVECTOR_DEEP) {
    return pvector_append_unsafe(pvector_digit_range_unsafe(digit_obj, 0, digit_len),
                                 right_obj);
  }

  e2 = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[2];
  e3 = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[3];
  if (digit_len == 2) {
    left_prefix = make_digit_from_fields(1, e0, NULL, NULL, NULL);
    left_suffix = make_digit_from_fields(1, e1, NULL, NULL, NULL);
    left_prefix_len = 1;
  } else if (digit_len == 3) {
    left_prefix = make_digit_from_fields(1, e0, NULL, NULL, NULL);
    left_suffix = make_digit_from_fields(2, e1, e2, NULL, NULL);
    left_prefix_len = 1;
  } else if (digit_len == 4) {
    left_prefix = make_digit_from_fields(2, e0, e1, NULL, NULL);
    left_suffix = make_digit_from_fields(2, e2, e3, NULL, NULL);
    left_prefix_len = 2;
  } else {
    scheme_signal_error("internal error: pvector prepend digit length is not 1..4");
    return NULL;
  }

  right_prefix = SCHEME_PVECTOR_A(right_obj);
  right_middle = SCHEME_PVECTOR_B(right_obj);
  right_suffix = SCHEME_PVECTOR_C(right_obj);
  right_suffix_len = SCHEME_PVECTOR_SUFFIX_LEN(right_obj);
  len = digit_len + SCHEME_PVECTOR_LENGTH(right_obj);
  middle = node_tree_from_digit_pair(left_suffix, right_prefix);
  middle = node_tree_join(middle, right_middle);

  return make_deep_pvector(len, left_prefix, middle, right_suffix,
                           left_prefix_len, right_suffix_len);
}

static Scheme_Object *
pvector_append_digit_unsafe(Scheme_Object *left_obj,
                            Scheme_Object *digit_obj,
                            int digit_len)
{
  Scheme_Object *left_prefix, *left_middle, *left_suffix;
  Scheme_Object *right_prefix, *right_suffix, *middle;
  Scheme_Object *left_value;
  Scheme_Object *e0, *e1, *e2, *e3;
  intptr_t len;
  int left_shape, left_prefix_len, right_suffix_len;

  if (digit_len <= 0) {
    return left_obj;
  } else if (SCHEME_PVECTOR_SHAPE(left_obj) == SCHEME_PVECTOR_EMPTY) {
    return pvector_digit_range_unsafe(digit_obj, 0, digit_len);
  }

  e0 = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[0];
  if (digit_len == 1) {
    return pvector_cons_right_unsafe(left_obj, e0);
  }

  e1 = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[1];
  left_shape = SCHEME_PVECTOR_SHAPE(left_obj);
  if (left_shape == SCHEME_PVECTOR_SINGLE) {
    left_value = SCHEME_PVECTOR_A(left_obj);
    if (digit_len == 2) {
      return pvector_from_small_fields(3, left_value, e0, e1, NULL);
    }

    e2 = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[2];
    if (digit_len == 3) {
      return pvector_from_small_fields(4, left_value, e0, e1, e2);
    }

    e3 = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[3];
    if (digit_len == 4) {
      return make_deep_pvector(5,
                               make_digit_from_fields(2, left_value, e0, NULL, NULL),
                               scheme_false,
                               make_digit_from_fields(3, e1, e2, e3, NULL),
                               2, 3);
    }

    scheme_signal_error("internal error: pvector append digit length is not 1..4");
    return NULL;
  }

  if (left_shape != SCHEME_PVECTOR_DEEP) {
    return pvector_append_unsafe(left_obj,
                                 pvector_digit_range_unsafe(digit_obj, 0, digit_len));
  }

  e2 = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[2];
  e3 = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[3];
  if (digit_len == 2) {
    right_prefix = make_digit_from_fields(1, e0, NULL, NULL, NULL);
    right_suffix = make_digit_from_fields(1, e1, NULL, NULL, NULL);
    right_suffix_len = 1;
  } else if (digit_len == 3) {
    right_prefix = make_digit_from_fields(1, e0, NULL, NULL, NULL);
    right_suffix = make_digit_from_fields(2, e1, e2, NULL, NULL);
    right_suffix_len = 2;
  } else if (digit_len == 4) {
    right_prefix = make_digit_from_fields(2, e0, e1, NULL, NULL);
    right_suffix = make_digit_from_fields(2, e2, e3, NULL, NULL);
    right_suffix_len = 2;
  } else {
    scheme_signal_error("internal error: pvector append digit length is not 1..4");
    return NULL;
  }

  left_prefix = SCHEME_PVECTOR_A(left_obj);
  left_middle = SCHEME_PVECTOR_B(left_obj);
  left_suffix = SCHEME_PVECTOR_C(left_obj);
  left_prefix_len = SCHEME_PVECTOR_PREFIX_LEN(left_obj);
  len = SCHEME_PVECTOR_LENGTH(left_obj) + digit_len;
  middle = node_tree_from_digit_pair(left_suffix, right_prefix);
  middle = node_tree_join(left_middle, middle);

  return make_deep_pvector(len, left_prefix, middle, right_suffix,
                           left_prefix_len, right_suffix_len);
}

static Scheme_Object *
pvector_take_unsafe(Scheme_Object *pv_obj, intptr_t pos)
{
  Scheme_Object *prefix, *middle, *suffix;
  Scheme_Object *prefix_part, *suffix_part;
  intptr_t len, prefix_len, suffix_len, suffix_start;

  len = SCHEME_PVECTOR_LENGTH(pv_obj);
  if (pos <= 0) {
    return core_pvector_empty;
  } else if (pos >= len) {
    return pv_obj;
  } else if (SCHEME_PVECTOR_SHAPE(pv_obj) != SCHEME_PVECTOR_DEEP) {
    scheme_signal_error("internal error: pvector take reached unexpected shape");
    return NULL;
  }

  prefix = SCHEME_PVECTOR_A(pv_obj);
  middle = SCHEME_PVECTOR_B(pv_obj);
  suffix = SCHEME_PVECTOR_C(pv_obj);
  prefix_len = SCHEME_PVECTOR_PREFIX_LEN(pv_obj);
  suffix_len = SCHEME_PVECTOR_SUFFIX_LEN(pv_obj);
  suffix_start = len - suffix_len;

  if (pos <= prefix_len) {
    return pvector_digit_range_unsafe(prefix, 0, (int)pos);
  } else if (pos >= suffix_start) {
    if (pos > suffix_start) {
      prefix_part = make_digit_slice_unsafe(prefix, 0, (int)prefix_len);
      suffix_part = make_digit_slice_unsafe(suffix,
                                            0,
                                            (int)(pos - suffix_start));
      return make_deep_pvector(pos, prefix_part, middle, suffix_part,
                               (int)prefix_len,
                               (int)(pos - suffix_start));
    }
    return pvector_from_prefix_middle_digit_unsafe(prefix,
                                                   (int)prefix_len,
                                                   middle);
  } else if (SCHEME_FALSEP(middle)) {
    scheme_signal_error("internal error: pvector take expected a middle tree");
    return NULL;
  }

  return pvector_prepend_digit_unsafe(prefix,
                                      (int)prefix_len,
                                      node_tree_take_unsafe(middle,
                                                            pos - prefix_len));
}

static Scheme_Object *
pvector_drop_unsafe(Scheme_Object *pv_obj, intptr_t pos)
{
  Scheme_Object *prefix, *middle, *suffix;
  Scheme_Object *prefix_rest, *suffix_part;
  intptr_t len, prefix_len, suffix_len, suffix_start;

  len = SCHEME_PVECTOR_LENGTH(pv_obj);
  if (pos <= 0) {
    return pv_obj;
  } else if (pos >= len) {
    return core_pvector_empty;
  } else if (SCHEME_PVECTOR_SHAPE(pv_obj) != SCHEME_PVECTOR_DEEP) {
    scheme_signal_error("internal error: pvector drop reached unexpected shape");
    return NULL;
  }

  prefix = SCHEME_PVECTOR_A(pv_obj);
  middle = SCHEME_PVECTOR_B(pv_obj);
  suffix = SCHEME_PVECTOR_C(pv_obj);
  prefix_len = SCHEME_PVECTOR_PREFIX_LEN(pv_obj);
  suffix_len = SCHEME_PVECTOR_SUFFIX_LEN(pv_obj);
  suffix_start = len - suffix_len;

  if (pos <= prefix_len) {
    if (pos < prefix_len) {
      prefix_rest = make_digit_slice_unsafe(prefix, (int)pos, (int)prefix_len);
      return make_deep_pvector(len - pos, prefix_rest, middle, suffix,
                               (int)(prefix_len - pos), (int)suffix_len);
    } else {
      return pvector_from_middle_suffix_digit_unsafe(middle,
                                                     suffix,
                                                     (int)suffix_len);
    }
  } else if (pos >= suffix_start) {
    return pvector_digit_range_unsafe(suffix,
                                      (int)(pos - suffix_start),
                                      (int)suffix_len);
  } else if (SCHEME_FALSEP(middle)) {
    scheme_signal_error("internal error: pvector drop expected a middle tree");
    return NULL;
  }

  return pvector_append_digit_unsafe(node_tree_drop_unsafe(middle,
                                                           pos - prefix_len),
                                     suffix,
                                     (int)suffix_len);
}

static Scheme_Object *
node_tree_copy_range_unsafe(Scheme_Object *node_obj, intptr_t start, intptr_t end)
{
  Scheme_Object *a, *b, *c, *part, *result;
  intptr_t a_measure, b_measure, c_measure, len;
  intptr_t child_start, child_end, overlap_start, overlap_end;
  int arity, level;

  len = end - start;
  if (len == 0) {
    return core_pvector_empty;
  } else if ((start == 0) && (end == SCHEME_PVECTOR_NODE_MEASURE(node_obj))) {
    return pvector_from_node_tree_unsafe(node_obj);
  } else if (len <= 3 && SCHEME_PVECTOR_NODE_LEVEL(node_obj) == 0) {
    return pvector_leaf_node_range_unsafe(node_obj, start, end);
  } else if (start == 0) {
    return node_tree_take_unsafe(node_obj, end);
  } else if (end == SCHEME_PVECTOR_NODE_MEASURE(node_obj)) {
    return node_tree_drop_unsafe(node_obj, start);
  }

  arity = SCHEME_PVECTOR_NODE_ARITY(node_obj);
  level = SCHEME_PVECTOR_NODE_LEVEL(node_obj);
  a = SCHEME_PVECTOR_NODE_A(node_obj);
  b = SCHEME_PVECTOR_NODE_B(node_obj);
  c = SCHEME_PVECTOR_NODE_C(node_obj);
  a_measure = pvector_child_measure(a);
  b_measure = pvector_child_measure(b);
  c_measure = (arity == 3) ? pvector_child_measure(c) : 0;
  result = core_pvector_empty;

  child_start = 0;
  child_end = a_measure;
  if ((start < child_end) && (end > child_start)) {
    overlap_start = (start > child_start) ? start : child_start;
    overlap_end = (end < child_end) ? end : child_end;
    if ((overlap_start == child_start) && (overlap_end == child_end)) {
      result = pvector_append_tree_child_unsafe(result, a);
    } else if (level == 0) {
      scheme_signal_error("internal error: pvector node copy reached partial scalar child");
      return NULL;
    } else {
      part = node_tree_copy_range_unsafe(a,
                                         overlap_start - child_start,
                                         overlap_end - child_start);
      result = pvector_append_pvector_part_unsafe(result, part);
    }
  }

  child_start = a_measure;
  child_end = child_start + b_measure;
  if ((start < child_end) && (end > child_start)) {
    overlap_start = (start > child_start) ? start : child_start;
    overlap_end = (end < child_end) ? end : child_end;
    if ((overlap_start == child_start) && (overlap_end == child_end)) {
      result = pvector_append_tree_child_unsafe(result, b);
    } else if (level == 0) {
      scheme_signal_error("internal error: pvector node copy reached partial scalar child");
      return NULL;
    } else {
      part = node_tree_copy_range_unsafe(b,
                                         overlap_start - child_start,
                                         overlap_end - child_start);
      result = pvector_append_pvector_part_unsafe(result, part);
    }
  }

  if (arity == 3) {
    child_start = a_measure + b_measure;
    child_end = child_start + c_measure;
    if ((start < child_end) && (end > child_start)) {
      overlap_start = (start > child_start) ? start : child_start;
      overlap_end = (end < child_end) ? end : child_end;
      if ((overlap_start == child_start) && (overlap_end == child_end)) {
        result = pvector_append_tree_child_unsafe(result, c);
      } else if (level == 0) {
        scheme_signal_error("internal error: pvector node copy reached partial scalar child");
        return NULL;
      } else {
        part = node_tree_copy_range_unsafe(c,
                                           overlap_start - child_start,
                                           overlap_end - child_start);
        result = pvector_append_pvector_part_unsafe(result, part);
      }
    }
  }

  return result;
}

static Scheme_Object *
pvector_copy_range_unsafe(Scheme_Object *pv_obj, intptr_t start, intptr_t end)
{
  Scheme_Object *result, *part;
  Scheme_Object *prefix, *middle, *suffix;
  Scheme_Object *prefix_part = NULL, *suffix_part = NULL;
  intptr_t len, range_len, prefix_len, suffix_len, suffix_start;
  intptr_t overlap_start, overlap_end;
  int prefix_part_len = 0, suffix_part_len = 0;

  len = SCHEME_PVECTOR_LENGTH(pv_obj);
  range_len = end - start;
  if (range_len == 0) {
    return core_pvector_empty;
  } else if ((start == 0) && (end == len)) {
    return pv_obj;
  } else if (start == 0) {
    return pvector_take_unsafe(pv_obj, end);
  } else if (end == len) {
    return pvector_drop_unsafe(pv_obj, start);
  } else if (SCHEME_PVECTOR_SHAPE(pv_obj) != SCHEME_PVECTOR_DEEP) {
    scheme_signal_error("internal error: pvector copy reached unexpected shape");
    return NULL;
  }

  prefix = SCHEME_PVECTOR_A(pv_obj);
  middle = SCHEME_PVECTOR_B(pv_obj);
  suffix = SCHEME_PVECTOR_C(pv_obj);
  prefix_len = SCHEME_PVECTOR_PREFIX_LEN(pv_obj);
  suffix_len = SCHEME_PVECTOR_SUFFIX_LEN(pv_obj);
  suffix_start = len - suffix_len;

  if (end <= prefix_len) {
    return pvector_digit_range_unsafe(prefix, (int)start, (int)end);
  } else if (start >= suffix_start) {
    return pvector_digit_range_unsafe(suffix,
                                      (int)(start - suffix_start),
                                      (int)(end - suffix_start));
  } else if ((start < prefix_len) && (end > suffix_start)) {
    prefix_part = make_digit_slice_unsafe(prefix, (int)start, (int)prefix_len);
    suffix_part = make_digit_slice_unsafe(suffix,
                                          0,
                                          (int)(end - suffix_start));
    return make_deep_pvector(range_len,
                             prefix_part,
                             middle,
                             suffix_part,
                             (int)(prefix_len - start),
                             (int)(end - suffix_start));
  } else if ((start < prefix_len) && (end == suffix_start)) {
    prefix_part = make_digit_slice_unsafe(prefix, (int)start, (int)prefix_len);
    return pvector_from_prefix_middle_digit_unsafe(prefix_part,
                                                   (int)(prefix_len - start),
                                                   middle);
  } else if ((start == prefix_len) && (end > suffix_start)) {
    suffix_part = make_digit_slice_unsafe(suffix,
                                          0,
                                          (int)(end - suffix_start));
    return pvector_from_middle_suffix_digit_unsafe(middle,
                                                   suffix_part,
                                                   (int)(end - suffix_start));
  } else if ((start == prefix_len) && (end == suffix_start)) {
    return pvector_from_node_tree_unsafe(middle);
  }

  result = core_pvector_empty;

  if (start < prefix_len) {
    overlap_end = (end < prefix_len) ? end : prefix_len;
    prefix_part = make_digit_slice_unsafe(prefix, (int)start, (int)overlap_end);
    prefix_part_len = (int)(overlap_end - start);
  }

  if (!SCHEME_FALSEP(middle)
      && (start < suffix_start)
      && (end > prefix_len)) {
    overlap_start = (start > prefix_len) ? start : prefix_len;
    overlap_end = (end < suffix_start) ? end : suffix_start;
    part = node_tree_copy_range_unsafe(middle,
                                       overlap_start - prefix_len,
                                       overlap_end - prefix_len);
    result = part;
  }

  if (prefix_part) {
    result = pvector_prepend_digit_unsafe(prefix_part, prefix_part_len, result);
  }

  if (end > suffix_start) {
    overlap_start = (start > suffix_start) ? start : suffix_start;
    suffix_part = make_digit_slice_unsafe(suffix,
                                          (int)(overlap_start - suffix_start),
                                          (int)(end - suffix_start));
    suffix_part_len = (int)(end - overlap_start);
    result = pvector_append_digit_unsafe(result,
                                         suffix_part,
                                         suffix_part_len);
  }

  return result;
}

static Scheme_Object *
pvector_tree_child_to_pvector_unsafe(Scheme_Object *child)
{
  if (SCHEME_PVECTOR_NODEP(child)
      && (SCHEME_PVECTOR_NODE_KIND(child) == SCHEME_PVECTOR_NODE_TREE)) {
    return pvector_from_node_tree_unsafe(child);
  } else {
    return make_single_pvector(child);
  }
}

static Scheme_Object *
pvector_from_node_children_unsafe(int level, int count,
                                  Scheme_Object *a,
                                  Scheme_Object *b,
                                  Scheme_Object *c)
{
  Scheme_Object *prefix, *middle, *suffix;
  Scheme_Object *left_leaf = NULL, *right_leaf = NULL;
  Scheme_Object *left_rest = NULL, *right_rest = NULL;
  intptr_t len;
  int prefix_len, suffix_len;

  if (count == 1) {
    return pvector_tree_child_to_pvector_unsafe(a);
  } else if (level == 0) {
    return pvector_from_small_fields(count, a, b, c, NULL);
  } else if (count == 2) {
    len = SCHEME_PVECTOR_NODE_MEASURE(a) + SCHEME_PVECTOR_NODE_MEASURE(b);
    node_tree_pop_left_leaf(a, &left_leaf, &left_rest);
    node_tree_pop_right_leaf(b, &right_leaf, &right_rest);
    middle = node_tree_join(left_rest, right_rest);
  } else if (count == 3) {
    len = (SCHEME_PVECTOR_NODE_MEASURE(a)
           + SCHEME_PVECTOR_NODE_MEASURE(b)
           + SCHEME_PVECTOR_NODE_MEASURE(c));
    node_tree_pop_left_leaf(a, &left_leaf, &left_rest);
    node_tree_pop_right_leaf(c, &right_leaf, &right_rest);
    middle = node_tree_join(left_rest, b);
    middle = node_tree_join(middle, right_rest);
  } else {
    scheme_signal_error("internal error: pvector node child rebuild arity is not 1..3");
    return NULL;
  }

  prefix_len = SCHEME_PVECTOR_NODE_ARITY(left_leaf);
  suffix_len = SCHEME_PVECTOR_NODE_ARITY(right_leaf);
  prefix = make_digit_from_leaf_node(left_leaf);
  suffix = make_digit_from_leaf_node(right_leaf);
  return make_deep_pvector(len, prefix, middle, suffix,
                           prefix_len, suffix_len);
}

static Scheme_Object *
pvector_append_node_tree_unsafe(Scheme_Object *pv_obj, Scheme_Object *node_obj)
{
  Scheme_Object *left_prefix, *left_middle, *left_suffix;
  Scheme_Object *right_prefix, *right_middle, *right_suffix;
  Scheme_Object *left_value;
  Scheme_Object *left_leaf = NULL, *right_leaf = NULL, *middle_rest = NULL;
  Scheme_Object *middle;
  Scheme_PVector_Node *node;
  intptr_t len;
  int left_prefix_len, right_suffix_len, level;

  if (SCHEME_FALSEP(node_obj)) {
    return pv_obj;
  }

  level = SCHEME_PVECTOR_NODE_LEVEL(node_obj);
  if (level == 0) {
    node = (Scheme_PVector_Node *)node_obj;
    pv_obj = pvector_cons_right_unsafe(pv_obj, node->a);
    pv_obj = pvector_cons_right_unsafe(pv_obj, node->b);
    if (node->arity == 3) {
      pv_obj = pvector_cons_right_unsafe(pv_obj, node->c);
    }
    return pv_obj;
  } else if (SCHEME_PVECTOR_SHAPE(pv_obj) == SCHEME_PVECTOR_EMPTY) {
    return pvector_from_node_tree_unsafe(node_obj);
  } else if (SCHEME_PVECTOR_SHAPE(pv_obj) == SCHEME_PVECTOR_SINGLE) {
    left_value = SCHEME_PVECTOR_A(pv_obj);
    node_tree_pop_left_leaf(node_obj, &left_leaf, &middle_rest);
    if (SCHEME_FALSEP(middle_rest)) {
      return pvector_cons_left_unsafe(pvector_from_node_tree_unsafe(node_obj),
                                      left_value);
    }

    node_tree_pop_right_leaf(middle_rest, &right_leaf, &right_middle);
    right_prefix = make_digit_from_value_and_leaf_node(left_value, left_leaf);
    right_suffix = make_digit_from_leaf_node(right_leaf);
    right_suffix_len = SCHEME_PVECTOR_NODE_ARITY(right_leaf);
    return make_deep_pvector(SCHEME_PVECTOR_NODE_MEASURE(node_obj) + 1,
                             right_prefix,
                             right_middle,
                             right_suffix,
                             SCHEME_PVECTOR_NODE_ARITY(left_leaf) + 1,
                             right_suffix_len);
  }

  len = SCHEME_PVECTOR_LENGTH(pv_obj) + SCHEME_PVECTOR_NODE_MEASURE(node_obj);
  left_prefix = SCHEME_PVECTOR_A(pv_obj);
  left_middle = SCHEME_PVECTOR_B(pv_obj);
  left_suffix = SCHEME_PVECTOR_C(pv_obj);
  left_prefix_len = SCHEME_PVECTOR_PREFIX_LEN(pv_obj);

  node_tree_pop_left_leaf(node_obj, &left_leaf, &middle_rest);
  node_tree_pop_right_leaf(middle_rest, &right_leaf, &right_middle);
  right_prefix = make_digit_from_leaf_node(left_leaf);
  right_suffix = make_digit_from_leaf_node(right_leaf);
  right_suffix_len = SCHEME_PVECTOR_NODE_ARITY(right_leaf);

  middle = node_tree_from_digit_pair(left_suffix, right_prefix);
  middle = node_tree_join(left_middle, middle);
  middle = node_tree_join(middle, right_middle);

  return make_deep_pvector(len, left_prefix, middle, right_suffix,
                           left_prefix_len, right_suffix_len);
}

static Scheme_Object *
pvector_append_tree_child_unsafe(Scheme_Object *pv_obj, Scheme_Object *child)
{
  if (SCHEME_PVECTOR_NODEP(child)
      && (SCHEME_PVECTOR_NODE_KIND(child) == SCHEME_PVECTOR_NODE_TREE)) {
    return pvector_append_node_tree_unsafe(pv_obj, child);
  } else {
    return pvector_cons_right_unsafe(pv_obj, child);
  }
}

static Scheme_Object *
pvector_append_pvector_part_unsafe(Scheme_Object *left_obj,
                                   Scheme_Object *right_obj)
{
  if (SCHEME_PVECTOR_SHAPE(left_obj) == SCHEME_PVECTOR_EMPTY) {
    return right_obj;
  } else {
    return pvector_append_unsafe(left_obj, right_obj);
  }
}

static Scheme_Object *
pvector_prepend_node_tree_unsafe(Scheme_Object *node_obj, Scheme_Object *pv_obj)
{
  Scheme_Object *left_prefix, *left_middle, *left_suffix;
  Scheme_Object *right_prefix, *right_middle, *right_suffix;
  Scheme_Object *right_value;
  Scheme_Object *left_leaf = NULL, *right_leaf = NULL, *middle_rest = NULL;
  Scheme_Object *middle;
  Scheme_PVector_Node *node;
  intptr_t len;
  int left_prefix_len, right_suffix_len, level;

  if (SCHEME_FALSEP(node_obj)) {
    return pv_obj;
  }

  level = SCHEME_PVECTOR_NODE_LEVEL(node_obj);
  if (level == 0) {
    node = (Scheme_PVector_Node *)node_obj;
    if (node->arity == 3) {
      pv_obj = pvector_cons_left_unsafe(pv_obj, node->c);
    }
    pv_obj = pvector_cons_left_unsafe(pv_obj, node->b);
    pv_obj = pvector_cons_left_unsafe(pv_obj, node->a);
    return pv_obj;
  } else if (SCHEME_PVECTOR_SHAPE(pv_obj) == SCHEME_PVECTOR_EMPTY) {
    return pvector_from_node_tree_unsafe(node_obj);
  } else if (SCHEME_PVECTOR_SHAPE(pv_obj) == SCHEME_PVECTOR_SINGLE) {
    right_value = SCHEME_PVECTOR_A(pv_obj);
    node_tree_pop_right_leaf(node_obj, &right_leaf, &middle_rest);
    if (SCHEME_FALSEP(middle_rest)) {
      return pvector_cons_right_unsafe(pvector_from_node_tree_unsafe(node_obj),
                                       right_value);
    }

    node_tree_pop_left_leaf(middle_rest, &left_leaf, &left_middle);
    left_prefix = make_digit_from_leaf_node(left_leaf);
    left_suffix = make_digit_from_leaf_node_and_value(right_leaf, right_value);
    left_prefix_len = SCHEME_PVECTOR_NODE_ARITY(left_leaf);
    return make_deep_pvector(SCHEME_PVECTOR_NODE_MEASURE(node_obj) + 1,
                             left_prefix,
                             left_middle,
                             left_suffix,
                             left_prefix_len,
                             SCHEME_PVECTOR_NODE_ARITY(right_leaf) + 1);
  }

  len = SCHEME_PVECTOR_NODE_MEASURE(node_obj) + SCHEME_PVECTOR_LENGTH(pv_obj);
  right_prefix = SCHEME_PVECTOR_A(pv_obj);
  right_middle = SCHEME_PVECTOR_B(pv_obj);
  right_suffix = SCHEME_PVECTOR_C(pv_obj);
  right_suffix_len = SCHEME_PVECTOR_SUFFIX_LEN(pv_obj);

  node_tree_pop_left_leaf(node_obj, &left_leaf, &middle_rest);
  node_tree_pop_right_leaf(middle_rest, &right_leaf, &left_middle);
  left_prefix = make_digit_from_leaf_node(left_leaf);
  left_suffix = make_digit_from_leaf_node(right_leaf);
  left_prefix_len = SCHEME_PVECTOR_NODE_ARITY(left_leaf);

  middle = node_tree_from_digit_pair(left_suffix, right_prefix);
  middle = node_tree_join(left_middle, middle);
  middle = node_tree_join(middle, right_middle);

  return make_deep_pvector(len, left_prefix, middle, right_suffix,
                           left_prefix_len, right_suffix_len);
}

static Scheme_Object *
pvector_prepend_tree_child_unsafe(Scheme_Object *child, Scheme_Object *pv_obj)
{
  if (SCHEME_PVECTOR_NODEP(child)
      && (SCHEME_PVECTOR_NODE_KIND(child) == SCHEME_PVECTOR_NODE_TREE)) {
    return pvector_prepend_node_tree_unsafe(child, pv_obj);
  } else {
    return pvector_cons_left_unsafe(pv_obj, child);
  }
}

static Scheme_Object *
node_tree_take_unsafe(Scheme_Object *node_obj, intptr_t pos)
{
  Scheme_Object *a, *b, *c, *part;
  intptr_t measure, a_measure, b_measure, c_measure;
  int arity, level;

  measure = SCHEME_PVECTOR_NODE_MEASURE(node_obj);
  if (pos <= 0) {
    return core_pvector_empty;
  } else if (pos >= measure) {
    return pvector_from_node_tree_unsafe(node_obj);
  }

  arity = SCHEME_PVECTOR_NODE_ARITY(node_obj);
  level = SCHEME_PVECTOR_NODE_LEVEL(node_obj);
  a = SCHEME_PVECTOR_NODE_A(node_obj);
  b = SCHEME_PVECTOR_NODE_B(node_obj);
  c = SCHEME_PVECTOR_NODE_C(node_obj);
  a_measure = pvector_child_measure(a);
  b_measure = pvector_child_measure(b);
  c_measure = (arity == 3) ? pvector_child_measure(c) : 0;

  if (pos < a_measure) {
    if (SCHEME_PVECTOR_NODEP(a)
        && (SCHEME_PVECTOR_NODE_KIND(a) == SCHEME_PVECTOR_NODE_TREE)) {
      return node_tree_take_unsafe(a, pos);
    } else {
      scheme_signal_error("internal error: pvector node take reached scalar child");
      return NULL;
    }
  } else if (pos == a_measure) {
    return pvector_from_node_children_unsafe(level, 1, a, NULL, NULL);
  }

  pos -= a_measure;
  if (pos < b_measure) {
    if (SCHEME_PVECTOR_NODEP(b)
        && (SCHEME_PVECTOR_NODE_KIND(b) == SCHEME_PVECTOR_NODE_TREE)) {
      part = node_tree_take_unsafe(b, pos);
      return pvector_prepend_tree_child_unsafe(a, part);
    } else {
      scheme_signal_error("internal error: pvector node take reached scalar child");
      return NULL;
    }
  } else if (pos == b_measure) {
    return pvector_from_node_children_unsafe(level, 2, a, b, NULL);
  }

  if (arity == 2) {
    scheme_signal_error("internal error: pvector node take position is out of range");
    return NULL;
  }

  pos -= b_measure;
  if (pos < c_measure) {
    if (SCHEME_PVECTOR_NODEP(c)
        && (SCHEME_PVECTOR_NODE_KIND(c) == SCHEME_PVECTOR_NODE_TREE)) {
      part = node_tree_take_unsafe(c, pos);
      part = pvector_prepend_tree_child_unsafe(b, part);
      return pvector_prepend_tree_child_unsafe(a, part);
    } else {
      scheme_signal_error("internal error: pvector node take reached scalar child");
      return NULL;
    }
  } else if (pos == c_measure) {
    return pvector_from_node_children_unsafe(level, 3, a, b, c);
  }

  scheme_signal_error("internal error: pvector node take position is out of range");
  return NULL;
}

static Scheme_Object *
node_tree_drop_unsafe(Scheme_Object *node_obj, intptr_t pos)
{
  Scheme_Object *a, *b, *c, *result;
  intptr_t measure, a_measure, b_measure, c_measure;
  int arity, level;

  measure = SCHEME_PVECTOR_NODE_MEASURE(node_obj);
  if (pos <= 0) {
    return pvector_from_node_tree_unsafe(node_obj);
  } else if (pos >= measure) {
    return core_pvector_empty;
  }

  arity = SCHEME_PVECTOR_NODE_ARITY(node_obj);
  level = SCHEME_PVECTOR_NODE_LEVEL(node_obj);
  a = SCHEME_PVECTOR_NODE_A(node_obj);
  b = SCHEME_PVECTOR_NODE_B(node_obj);
  c = SCHEME_PVECTOR_NODE_C(node_obj);
  a_measure = pvector_child_measure(a);
  b_measure = pvector_child_measure(b);
  c_measure = (arity == 3) ? pvector_child_measure(c) : 0;

  if (pos < a_measure) {
    if (SCHEME_PVECTOR_NODEP(a)
        && (SCHEME_PVECTOR_NODE_KIND(a) == SCHEME_PVECTOR_NODE_TREE)) {
      result = node_tree_drop_unsafe(a, pos);
    } else {
      scheme_signal_error("internal error: pvector node drop reached scalar child");
      return NULL;
    }
    result = pvector_append_tree_child_unsafe(result, b);
    if (arity == 3) {
      result = pvector_append_tree_child_unsafe(result, c);
    }
    return result;
  } else if (pos == a_measure) {
    if (arity == 3) {
      return pvector_from_node_children_unsafe(level, 2, b, c, NULL);
    } else {
      return pvector_from_node_children_unsafe(level, 1, b, NULL, NULL);
    }
  }

  pos -= a_measure;
  if (pos < b_measure) {
    if (SCHEME_PVECTOR_NODEP(b)
        && (SCHEME_PVECTOR_NODE_KIND(b) == SCHEME_PVECTOR_NODE_TREE)) {
      result = node_tree_drop_unsafe(b, pos);
    } else {
      scheme_signal_error("internal error: pvector node drop reached scalar child");
      return NULL;
    }
    if (arity == 3) {
      result = pvector_append_tree_child_unsafe(result, c);
    }
    return result;
  } else if (pos == b_measure) {
    if (arity == 3) {
      return pvector_from_node_children_unsafe(level, 1, c, NULL, NULL);
    } else {
      return core_pvector_empty;
    }
  }

  if (arity == 2) {
    scheme_signal_error("internal error: pvector node drop position is out of range");
    return NULL;
  }

  pos -= b_measure;
  if (pos < c_measure) {
    if (SCHEME_PVECTOR_NODEP(c)
        && (SCHEME_PVECTOR_NODE_KIND(c) == SCHEME_PVECTOR_NODE_TREE)) {
      return node_tree_drop_unsafe(c, pos);
    } else {
      scheme_signal_error("internal error: pvector node drop reached scalar child");
      return NULL;
    }
  } else if (pos == c_measure) {
    return core_pvector_empty;
  }

  scheme_signal_error("internal error: pvector node drop position is out of range");
  return NULL;
}

static void
node_tree_split_at_unsafe(Scheme_Object *node_obj, intptr_t pos,
                          Scheme_Object **out_left, Scheme_Object **out_right)
{
  Scheme_Object *a, *b, *c, *left, *right, *child_left, *child_right;
  intptr_t measure, a_measure, b_measure, c_measure;
  int arity, level;

  measure = SCHEME_PVECTOR_NODE_MEASURE(node_obj);
  if (pos <= 0) {
    right = pvector_from_node_tree_unsafe(node_obj);
    *out_left = core_pvector_empty;
    *out_right = right;
    return;
  } else if (pos >= measure) {
    left = pvector_from_node_tree_unsafe(node_obj);
    *out_left = left;
    *out_right = core_pvector_empty;
    return;
  }

  arity = SCHEME_PVECTOR_NODE_ARITY(node_obj);
  level = SCHEME_PVECTOR_NODE_LEVEL(node_obj);
  a = SCHEME_PVECTOR_NODE_A(node_obj);
  b = SCHEME_PVECTOR_NODE_B(node_obj);
  c = SCHEME_PVECTOR_NODE_C(node_obj);
  a_measure = pvector_child_measure(a);
  b_measure = pvector_child_measure(b);
  c_measure = (arity == 3) ? pvector_child_measure(c) : 0;

  if (pos < a_measure) {
    node_tree_split_at_unsafe(a, pos, &left, &right);
    right = pvector_append_tree_child_unsafe(right, b);
    if (arity == 3) {
      right = pvector_append_tree_child_unsafe(right, c);
    }
    *out_left = left;
    *out_right = right;
    return;
  }

  if (pos == a_measure) {
    left = pvector_from_node_children_unsafe(level, 1, a, NULL, NULL);
    if (arity == 3) {
      right = pvector_from_node_children_unsafe(level, 2, b, c, NULL);
    } else {
      right = pvector_from_node_children_unsafe(level, 1, b, NULL, NULL);
    }
    *out_left = left;
    *out_right = right;
    return;
  }

  pos -= a_measure;
  if (pos < b_measure) {
    node_tree_split_at_unsafe(b, pos, &child_left, &child_right);
    left = pvector_prepend_tree_child_unsafe(a, child_left);
    right = child_right;
    if (arity == 3) {
      right = pvector_append_tree_child_unsafe(right, c);
    }
    *out_left = left;
    *out_right = right;
    return;
  }

  if (arity == 2) {
    left = pvector_from_node_children_unsafe(level, 2, a, b, NULL);
    *out_left = left;
    *out_right = core_pvector_empty;
    return;
  }

  if (pos == b_measure) {
    left = pvector_from_node_children_unsafe(level, 2, a, b, NULL);
    right = pvector_from_node_children_unsafe(level, 1, c, NULL, NULL);
    *out_left = left;
    *out_right = right;
    return;
  }

  pos -= b_measure;
  if (pos < c_measure) {
    node_tree_split_at_unsafe(c, pos, &child_left, &child_right);
    left = pvector_prepend_tree_child_unsafe(b, child_left);
    left = pvector_prepend_tree_child_unsafe(a, left);
    *out_left = left;
    *out_right = child_right;
    return;
  }

  scheme_signal_error("internal error: pvector node split position is out of range");
}

static void
node_tree_split_value_unsafe(Scheme_Object *node_obj, intptr_t pos,
                             Scheme_Object **out_left,
                             Scheme_Object **out_value,
                             Scheme_Object **out_right)
{
  Scheme_Object *a, *b, *c, *left, *right, *child_left, *child_right;
  intptr_t measure, a_measure, b_measure, c_measure;
  int arity, level;

  measure = SCHEME_PVECTOR_NODE_MEASURE(node_obj);
  if ((pos < 0) || (pos >= measure)) {
    scheme_signal_error("internal error: pvector node split value position is out of range");
    return;
  }

  arity = SCHEME_PVECTOR_NODE_ARITY(node_obj);
  level = SCHEME_PVECTOR_NODE_LEVEL(node_obj);
  a = SCHEME_PVECTOR_NODE_A(node_obj);
  b = SCHEME_PVECTOR_NODE_B(node_obj);
  c = SCHEME_PVECTOR_NODE_C(node_obj);

  if (level == 0) {
    if (pos == 0) {
      if (arity == 3) {
        right = pvector_from_node_children_unsafe(level, 2, b, c, NULL);
      } else {
        right = pvector_from_node_children_unsafe(level, 1, b, NULL, NULL);
      }
      *out_left = core_pvector_empty;
      *out_value = a;
      *out_right = right;
      return;
    } else if (pos == 1) {
      left = pvector_from_node_children_unsafe(level, 1, a, NULL, NULL);
      if (arity == 3) {
        right = pvector_from_node_children_unsafe(level, 1, c, NULL, NULL);
      } else {
        right = core_pvector_empty;
      }
      *out_left = left;
      *out_value = b;
      *out_right = right;
      return;
    } else if ((arity == 3) && (pos == 2)) {
      left = pvector_from_node_children_unsafe(level, 2, a, b, NULL);
      *out_left = left;
      *out_value = c;
      *out_right = core_pvector_empty;
      return;
    }

    scheme_signal_error("internal error: pvector leaf split value position is out of range");
    return;
  }

  a_measure = pvector_child_measure(a);
  b_measure = pvector_child_measure(b);
  c_measure = (arity == 3) ? pvector_child_measure(c) : 0;

  if (pos < a_measure) {
    node_tree_split_value_unsafe(a, pos, &left, out_value, &right);
    right = pvector_append_tree_child_unsafe(right, b);
    if (arity == 3) {
      right = pvector_append_tree_child_unsafe(right, c);
    }
    *out_left = left;
    *out_right = right;
    return;
  }

  pos -= a_measure;
  if (pos < b_measure) {
    node_tree_split_value_unsafe(b, pos, &child_left, out_value, &child_right);
    left = pvector_prepend_tree_child_unsafe(a, child_left);
    right = child_right;
    if (arity == 3) {
      right = pvector_append_tree_child_unsafe(right, c);
    }
    *out_left = left;
    *out_right = right;
    return;
  }

  if (arity == 2) {
    scheme_signal_error("internal error: pvector node split value position is out of range");
    return;
  }

  pos -= b_measure;
  if (pos < c_measure) {
    node_tree_split_value_unsafe(c, pos, &child_left, out_value, &right);
    left = pvector_prepend_tree_child_unsafe(b, child_left);
    left = pvector_prepend_tree_child_unsafe(a, left);
    *out_left = left;
    *out_right = right;
    return;
  }

  scheme_signal_error("internal error: pvector node split value position is out of range");
}

static void
pvector_split_at_unsafe(Scheme_Object *pv_obj, intptr_t pos,
                        Scheme_Object **out_left, Scheme_Object **out_right)
{
  Scheme_Object *prefix, *middle, *suffix;
  Scheme_Object *left, *right, *prefix_part, *middle_left, *middle_right;
  Scheme_Object *prefix_rest, *suffix_part;
  intptr_t len, prefix_len, suffix_len, suffix_start;

  len = SCHEME_PVECTOR_LENGTH(pv_obj);
  if (pos <= 0) {
    *out_left = core_pvector_empty;
    *out_right = pv_obj;
    return;
  } else if (pos >= len) {
    *out_left = pv_obj;
    *out_right = core_pvector_empty;
    return;
  } else if (SCHEME_PVECTOR_SHAPE(pv_obj) == SCHEME_PVECTOR_SINGLE) {
    scheme_signal_error("internal error: pvector split reached singleton interior");
    return;
  } else if (SCHEME_PVECTOR_SHAPE(pv_obj) != SCHEME_PVECTOR_DEEP) {
    scheme_signal_error("internal error: pvector split reached unexpected shape");
    return;
  }

  prefix = SCHEME_PVECTOR_A(pv_obj);
  middle = SCHEME_PVECTOR_B(pv_obj);
  suffix = SCHEME_PVECTOR_C(pv_obj);
  prefix_len = SCHEME_PVECTOR_PREFIX_LEN(pv_obj);
  suffix_len = SCHEME_PVECTOR_SUFFIX_LEN(pv_obj);
  suffix_start = len - suffix_len;

  if (pos <= prefix_len) {
    if (pos < prefix_len) {
      prefix_part = pvector_digit_range_unsafe(prefix, 0, (int)pos);
      prefix_rest = make_digit_slice_unsafe(prefix, (int)pos, (int)prefix_len);
      right = make_deep_pvector(len - pos, prefix_rest, middle, suffix,
                                (int)(prefix_len - pos), (int)suffix_len);
      *out_left = prefix_part;
      *out_right = right;
      return;
    }
    prefix_part = pvector_digit_range_unsafe(prefix, 0, (int)pos);
    right = pvector_from_middle_suffix_digit_unsafe(middle,
                                                    suffix,
                                                    (int)suffix_len);
    *out_left = prefix_part;
    *out_right = right;
    return;
  } else if (pos >= suffix_start) {
    if (pos > suffix_start) {
      prefix_part = make_digit_slice_unsafe(prefix, 0, (int)prefix_len);
      suffix_part = make_digit_slice_unsafe(suffix,
                                            0,
                                            (int)(pos - suffix_start));
      left = make_deep_pvector(pos, prefix_part, middle, suffix_part,
                               (int)prefix_len, (int)(pos - suffix_start));
      right = pvector_digit_range_unsafe(suffix,
                                         (int)(pos - suffix_start),
                                         (int)suffix_len);
      *out_left = left;
      *out_right = right;
      return;
    }
    left = pvector_from_prefix_middle_digit_unsafe(prefix,
                                                   (int)prefix_len,
                                                   middle);
    right = pvector_digit_range_unsafe(suffix,
                                       (int)(pos - suffix_start),
                                       (int)suffix_len);
    *out_left = left;
    *out_right = right;
    return;
  } else if (SCHEME_FALSEP(middle)) {
    scheme_signal_error("internal error: pvector split expected a middle tree");
    return;
  }

  node_tree_split_at_unsafe(middle,
                            pos - prefix_len,
                            &middle_left,
                            &middle_right);
  left = pvector_prepend_digit_unsafe(prefix, (int)prefix_len, middle_left);
  right = pvector_append_digit_unsafe(middle_right, suffix, (int)suffix_len);
  *out_left = left;
  *out_right = right;
}

static void
pvector_split_middle_unsafe(Scheme_Object *prefix,
                            int prefix_len,
                            Scheme_Object *middle,
                            Scheme_Object *suffix,
                            int suffix_len,
                            intptr_t middle_pos,
                            Scheme_Object **out_left,
                            Scheme_Object **out_value,
                            Scheme_Object **out_right)
{
  Scheme_Object *left, *right;
  Scheme_Object *middle_left, *middle_right;

  node_tree_split_value_unsafe(middle,
                               middle_pos,
                               &middle_left,
                               out_value,
                               &middle_right);
  left = pvector_prepend_digit_unsafe(prefix, prefix_len, middle_left);
  right = pvector_append_digit_unsafe(middle_right, suffix, suffix_len);
  *out_left = left;
  *out_right = right;
}

static Scheme_Object *
pvector_delete_middle_unsafe(Scheme_Object *prefix,
                             int prefix_len,
                             Scheme_Object *middle,
                             Scheme_Object *suffix,
                             int suffix_len,
                             intptr_t middle_pos,
                             Scheme_Object **out_value)
{
  Scheme_Object *middle_left, *middle_right, *result;

  node_tree_split_value_unsafe(middle,
                               middle_pos,
                               &middle_left,
                               out_value,
                               &middle_right);
  result = pvector_prepend_digit_unsafe(prefix, prefix_len, middle_left);
  result = pvector_append_pvector_part_unsafe(result, middle_right);
  return pvector_append_digit_unsafe(result, suffix, suffix_len);
}

static Scheme_Object *
pvector_insert_middle_unsafe(Scheme_Object *prefix,
                             int prefix_len,
                             Scheme_Object *middle,
                             Scheme_Object *suffix,
                             int suffix_len,
                             intptr_t middle_pos,
                             Scheme_Object *value)
{
  Scheme_Object *middle_left, *middle_right, *result;

  node_tree_split_at_unsafe(middle, middle_pos, &middle_left, &middle_right);
  result = pvector_insert_between_unsafe(middle_left, value, middle_right);
  result = pvector_prepend_digit_unsafe(prefix, prefix_len, result);
  return pvector_append_digit_unsafe(result, suffix, suffix_len);
}

static Scheme_Object *
pvector_append_unsafe(Scheme_Object *left_obj, Scheme_Object *right_obj)
{
  Scheme_Object *middle;
  Scheme_Object *left_prefix, *left_middle, *left_suffix;
  Scheme_Object *right_prefix, *right_middle, *right_suffix;
  intptr_t len;
  int left_prefix_len, left_shape, right_shape, right_suffix_len;

  left_shape = SCHEME_PVECTOR_SHAPE(left_obj);
  right_shape = SCHEME_PVECTOR_SHAPE(right_obj);

  if (left_shape == SCHEME_PVECTOR_EMPTY) {
    return right_obj;
  } else if (right_shape == SCHEME_PVECTOR_EMPTY) {
    return left_obj;
  } else if (left_shape == SCHEME_PVECTOR_SINGLE) {
    return pvector_cons_left_unsafe(right_obj, SCHEME_PVECTOR_A(left_obj));
  } else if (right_shape == SCHEME_PVECTOR_SINGLE) {
    return pvector_cons_right_unsafe(left_obj, SCHEME_PVECTOR_A(right_obj));
  }

  left_prefix = SCHEME_PVECTOR_A(left_obj);
  left_middle = SCHEME_PVECTOR_B(left_obj);
  left_suffix = SCHEME_PVECTOR_C(left_obj);
  right_prefix = SCHEME_PVECTOR_A(right_obj);
  right_middle = SCHEME_PVECTOR_B(right_obj);
  right_suffix = SCHEME_PVECTOR_C(right_obj);
  left_prefix_len = SCHEME_PVECTOR_PREFIX_LEN(left_obj);
  right_suffix_len = SCHEME_PVECTOR_SUFFIX_LEN(right_obj);
  len = SCHEME_PVECTOR_LENGTH(left_obj) + SCHEME_PVECTOR_LENGTH(right_obj);

  middle = node_tree_from_digit_pair(left_suffix, right_prefix);
  middle = node_tree_join(left_middle, middle);
  middle = node_tree_join(middle, right_middle);
  return make_deep_pvector(len, left_prefix, middle, right_suffix,
                           left_prefix_len, right_suffix_len);
}

static Scheme_Object *
pvector_insert_between_unsafe(Scheme_Object *left_obj,
                              Scheme_Object *value,
                              Scheme_Object *right_obj)
{
  Scheme_Object *middle;
  Scheme_Object *left_prefix, *left_middle, *left_suffix;
  Scheme_Object *right_prefix, *right_middle, *right_suffix;
  intptr_t len;
  int left_shape, right_shape, left_prefix_len, right_suffix_len;

  left_shape = SCHEME_PVECTOR_SHAPE(left_obj);
  right_shape = SCHEME_PVECTOR_SHAPE(right_obj);

  if (left_shape == SCHEME_PVECTOR_EMPTY) {
    return pvector_cons_left_unsafe(right_obj, value);
  } else if (right_shape == SCHEME_PVECTOR_EMPTY) {
    return pvector_cons_right_unsafe(left_obj, value);
  } else if ((left_shape != SCHEME_PVECTOR_DEEP)
             || (right_shape != SCHEME_PVECTOR_DEEP)) {
    left_obj = pvector_cons_right_unsafe(left_obj, value);
    return pvector_append_unsafe(left_obj, right_obj);
  }

  left_prefix = SCHEME_PVECTOR_A(left_obj);
  left_middle = SCHEME_PVECTOR_B(left_obj);
  left_suffix = SCHEME_PVECTOR_C(left_obj);
  right_prefix = SCHEME_PVECTOR_A(right_obj);
  right_middle = SCHEME_PVECTOR_B(right_obj);
  right_suffix = SCHEME_PVECTOR_C(right_obj);
  left_prefix_len = SCHEME_PVECTOR_PREFIX_LEN(left_obj);
  right_suffix_len = SCHEME_PVECTOR_SUFFIX_LEN(right_obj);
  len = SCHEME_PVECTOR_LENGTH(left_obj) + 1 + SCHEME_PVECTOR_LENGTH(right_obj);

  middle = node_tree_from_digit_value_digit(left_suffix, value, right_prefix);
  middle = node_tree_join(left_middle, middle);
  middle = node_tree_join(middle, right_middle);
  return make_deep_pvector(len, left_prefix, middle, right_suffix,
                           left_prefix_len, right_suffix_len);
}

static Scheme_Object *
pvector_append_deep_parts_unsafe(Scheme_Object *left_obj,
                                 intptr_t right_len,
                                 Scheme_Object *right_prefix,
                                 Scheme_Object *right_middle,
                                 Scheme_Object *right_suffix,
                                 int right_prefix_len,
                                 int right_suffix_len)
{
  Scheme_Object *middle;
  Scheme_Object *left_prefix, *left_middle, *left_suffix, *right_obj;
  intptr_t len;
  int left_shape, left_prefix_len;

  left_shape = SCHEME_PVECTOR_SHAPE(left_obj);
  if (left_shape == SCHEME_PVECTOR_EMPTY) {
    return make_deep_pvector(right_len, right_prefix, right_middle, right_suffix,
                             right_prefix_len, right_suffix_len);
  } else if (left_shape != SCHEME_PVECTOR_DEEP) {
    right_obj = make_deep_pvector(right_len,
                                  right_prefix,
                                  right_middle,
                                  right_suffix,
                                  right_prefix_len,
                                  right_suffix_len);
    return pvector_append_unsafe(left_obj, right_obj);
  }

  left_prefix = SCHEME_PVECTOR_A(left_obj);
  left_middle = SCHEME_PVECTOR_B(left_obj);
  left_suffix = SCHEME_PVECTOR_C(left_obj);
  left_prefix_len = SCHEME_PVECTOR_PREFIX_LEN(left_obj);
  len = SCHEME_PVECTOR_LENGTH(left_obj) + right_len;

  middle = node_tree_from_digit_pair(left_suffix, right_prefix);
  middle = node_tree_join(left_middle, middle);
  middle = node_tree_join(middle, right_middle);
  return make_deep_pvector(len, left_prefix, middle, right_suffix,
                           left_prefix_len, right_suffix_len);
}

static Scheme_Object *
pvector_append_after_pop_left_unsafe(Scheme_Object *left_obj,
                                     Scheme_Object *right_obj,
                                     Scheme_Object **out_value)
{
  Scheme_Object *right_prefix, *right_middle, *right_suffix;
  Scheme_Object *prefix_rest, *leaf = NULL, *middle_rest = NULL;
  intptr_t right_len;
  int right_shape, right_prefix_len, right_suffix_len;

  right_shape = SCHEME_PVECTOR_SHAPE(right_obj);
  if (right_shape == SCHEME_PVECTOR_EMPTY) {
    scheme_signal_error("internal error: pvector delete reached empty right side");
    return NULL;
  } else if (right_shape == SCHEME_PVECTOR_SINGLE) {
    *out_value = SCHEME_PVECTOR_A(right_obj);
    return left_obj;
  } else if (right_shape != SCHEME_PVECTOR_DEEP) {
    scheme_signal_error("internal error: pvector delete reached unexpected right shape");
    return NULL;
  }

  right_len = SCHEME_PVECTOR_LENGTH(right_obj);
  right_prefix = SCHEME_PVECTOR_A(right_obj);
  right_middle = SCHEME_PVECTOR_B(right_obj);
  right_suffix = SCHEME_PVECTOR_C(right_obj);
  right_prefix_len = SCHEME_PVECTOR_PREFIX_LEN(right_obj);
  right_suffix_len = SCHEME_PVECTOR_SUFFIX_LEN(right_obj);

  *out_value = SCHEME_PVECTOR_DIGIT_ELS(right_prefix)[0];
  if (right_prefix_len > 1) {
    prefix_rest = make_digit_without_first(right_prefix);
    return pvector_append_deep_parts_unsafe(left_obj,
                                            right_len - 1,
                                            prefix_rest,
                                            right_middle,
                                            right_suffix,
                                            right_prefix_len - 1,
                                            right_suffix_len);
  } else if (!SCHEME_FALSEP(right_middle)) {
    node_tree_pop_left_leaf(right_middle, &leaf, &middle_rest);
    prefix_rest = make_digit_from_leaf_node(leaf);
    return pvector_append_deep_parts_unsafe(left_obj,
                                            right_len - 1,
                                            prefix_rest,
                                            middle_rest,
                                            right_suffix,
                                            SCHEME_PVECTOR_NODE_ARITY(leaf),
                                            right_suffix_len);
  } else {
    return pvector_append_digit_unsafe(left_obj, right_suffix, right_suffix_len);
  }
}

static Scheme_Object *
pvector_apply_map_proc(Scheme_Object *proc, Scheme_Object *elem)
{
  Scheme_Object *arg[1];

  arg[0] = elem;
  return _scheme_apply(proc, 1, arg);
}

static void
pvector_apply_for_each_proc(Scheme_Object *proc, Scheme_Object *elem)
{
  Scheme_Object *arg[1];

  arg[0] = elem;
  (void)_scheme_apply_multi(proc, 1, arg);
}

static Scheme_Object *
pvector_map_digit_unsafe(Scheme_Object *digit_obj, Scheme_Object *proc)
{
  Scheme_Object *a = NULL, *b = NULL, *c = NULL, *d = NULL;
  int count;

  count = SCHEME_PVECTOR_DIGIT_COUNT(digit_obj);
  a = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[0];
  b = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[1];
  c = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[2];
  d = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[3];

  if (count > 0) a = pvector_apply_map_proc(proc, a);
  if (count > 1) b = pvector_apply_map_proc(proc, b);
  if (count > 2) c = pvector_apply_map_proc(proc, c);
  if (count > 3) d = pvector_apply_map_proc(proc, d);

  return make_digit_from_fields(count, a, b, c, d);
}

static Scheme_Object *
pvector_constant_digit_like(Scheme_Object *digit_obj, Scheme_Object *value)
{
  int count;

  count = SCHEME_PVECTOR_DIGIT_COUNT(digit_obj);
  return make_digit_from_fields(count,
                                value,
                                value,
                                value,
                                value);
}

static Scheme_Object *
pvector_map_node_unsafe(Scheme_Object *node_obj, Scheme_Object *proc)
{
  Scheme_Object *a, *b, *c;
  int arity, level;

  arity = SCHEME_PVECTOR_NODE_ARITY(node_obj);
  level = SCHEME_PVECTOR_NODE_LEVEL(node_obj);
  a = SCHEME_PVECTOR_NODE_A(node_obj);
  b = SCHEME_PVECTOR_NODE_B(node_obj);
  c = SCHEME_PVECTOR_NODE_C(node_obj);

  if (level == 0) {
    a = pvector_apply_map_proc(proc, a);
    b = pvector_apply_map_proc(proc, b);
    if (arity == 3) {
      c = pvector_apply_map_proc(proc, c);
    }
  } else {
    a = pvector_map_node_unsafe(a, proc);
    b = pvector_map_node_unsafe(b, proc);
    if (arity == 3) {
      c = pvector_map_node_unsafe(c, proc);
    }
  }

  if (arity == 2) {
    return make_node2(level, a, b);
  } else {
    return make_node3(level, a, b, c);
  }
}

static Scheme_Object *
pvector_constant_node_like(Scheme_Object *node_obj, Scheme_Object *value)
{
  Scheme_Object *a, *b, *c;
  int arity, level;

  arity = SCHEME_PVECTOR_NODE_ARITY(node_obj);
  level = SCHEME_PVECTOR_NODE_LEVEL(node_obj);
  a = SCHEME_PVECTOR_NODE_A(node_obj);
  b = SCHEME_PVECTOR_NODE_B(node_obj);
  c = SCHEME_PVECTOR_NODE_C(node_obj);

  if (level == 0) {
    a = value;
    b = value;
    if (arity == 3) {
      c = value;
    }
  } else {
    a = pvector_constant_node_like(a, value);
    b = pvector_constant_node_like(b, value);
    if (arity == 3) {
      c = pvector_constant_node_like(c, value);
    }
  }

  if (arity == 2) {
    return make_node2(level, a, b);
  } else {
    return make_node3(level, a, b, c);
  }
}

static Scheme_Object *
pvector_map_unsafe(Scheme_Object *pv_obj, Scheme_Object *proc)
{
  Scheme_Object *prefix, *middle, *suffix;
  Scheme_Object *a;
  intptr_t len;
  int shape, prefix_len, suffix_len;

  shape = SCHEME_PVECTOR_SHAPE(pv_obj);
  if (shape == SCHEME_PVECTOR_EMPTY) {
    return core_pvector_empty;
  } else if (shape == SCHEME_PVECTOR_SINGLE) {
    a = SCHEME_PVECTOR_A(pv_obj);
    return make_single_pvector(pvector_apply_map_proc(proc, a));
  }

  len = SCHEME_PVECTOR_LENGTH(pv_obj);
  prefix = SCHEME_PVECTOR_A(pv_obj);
  middle = SCHEME_PVECTOR_B(pv_obj);
  suffix = SCHEME_PVECTOR_C(pv_obj);
  prefix_len = SCHEME_PVECTOR_PREFIX_LEN(pv_obj);
  suffix_len = SCHEME_PVECTOR_SUFFIX_LEN(pv_obj);

  prefix = pvector_map_digit_unsafe(prefix, proc);
  if (!SCHEME_FALSEP(middle)) {
    middle = pvector_map_node_unsafe(middle, proc);
  }
  suffix = pvector_map_digit_unsafe(suffix, proc);

  return make_deep_pvector(len, prefix, middle, suffix,
                           prefix_len, suffix_len);
}

static Scheme_Object *
pvector_constant_map_unsafe(Scheme_Object *pv_obj, Scheme_Object *value)
{
  Scheme_Object *prefix, *middle, *suffix;
  intptr_t len;
  int shape, prefix_len, suffix_len;

  shape = SCHEME_PVECTOR_SHAPE(pv_obj);
  if (shape == SCHEME_PVECTOR_EMPTY) {
    return core_pvector_empty;
  } else if (shape == SCHEME_PVECTOR_SINGLE) {
    return make_single_pvector(value);
  }

  len = SCHEME_PVECTOR_LENGTH(pv_obj);
  prefix = SCHEME_PVECTOR_A(pv_obj);
  middle = SCHEME_PVECTOR_B(pv_obj);
  suffix = SCHEME_PVECTOR_C(pv_obj);
  prefix_len = SCHEME_PVECTOR_PREFIX_LEN(pv_obj);
  suffix_len = SCHEME_PVECTOR_SUFFIX_LEN(pv_obj);

  prefix = pvector_constant_digit_like(prefix, value);
  if (!SCHEME_FALSEP(middle)) {
    middle = pvector_constant_node_like(middle, value);
  }
  suffix = pvector_constant_digit_like(suffix, value);

  return make_deep_pvector(len, prefix, middle, suffix,
                           prefix_len, suffix_len);
}

static void
pvector_for_each_digit_unsafe(Scheme_Object *digit_obj, Scheme_Object *proc)
{
  Scheme_Object *a = NULL, *b = NULL, *c = NULL, *d = NULL;
  int count;

  count = SCHEME_PVECTOR_DIGIT_COUNT(digit_obj);
  a = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[0];
  b = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[1];
  c = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[2];
  d = SCHEME_PVECTOR_DIGIT_ELS(digit_obj)[3];

  if (count > 0) pvector_apply_for_each_proc(proc, a);
  if (count > 1) pvector_apply_for_each_proc(proc, b);
  if (count > 2) pvector_apply_for_each_proc(proc, c);
  if (count > 3) pvector_apply_for_each_proc(proc, d);
}

static void
pvector_for_each_node_unsafe(Scheme_Object *node_obj, Scheme_Object *proc)
{
  Scheme_Object *a, *b, *c;
  int arity, level;

  arity = SCHEME_PVECTOR_NODE_ARITY(node_obj);
  level = SCHEME_PVECTOR_NODE_LEVEL(node_obj);
  a = SCHEME_PVECTOR_NODE_A(node_obj);
  b = SCHEME_PVECTOR_NODE_B(node_obj);
  c = SCHEME_PVECTOR_NODE_C(node_obj);

  if (level == 0) {
    pvector_apply_for_each_proc(proc, a);
    pvector_apply_for_each_proc(proc, b);
    if (arity == 3) {
      pvector_apply_for_each_proc(proc, c);
    }
  } else {
    pvector_for_each_node_unsafe(a, proc);
    pvector_for_each_node_unsafe(b, proc);
    if (arity == 3) {
      pvector_for_each_node_unsafe(c, proc);
    }
  }
}

static void
pvector_for_each_unsafe(Scheme_Object *pv_obj, Scheme_Object *proc)
{
  Scheme_Object *prefix, *middle, *suffix, *a;
  int shape;

  shape = SCHEME_PVECTOR_SHAPE(pv_obj);
  if (shape == SCHEME_PVECTOR_EMPTY) {
    return;
  } else if (shape == SCHEME_PVECTOR_SINGLE) {
    a = SCHEME_PVECTOR_A(pv_obj);
    pvector_apply_for_each_proc(proc, a);
    return;
  }

  prefix = SCHEME_PVECTOR_A(pv_obj);
  middle = SCHEME_PVECTOR_B(pv_obj);
  suffix = SCHEME_PVECTOR_C(pv_obj);

  pvector_for_each_digit_unsafe(prefix, proc);
  if (!SCHEME_FALSEP(middle)) {
    pvector_for_each_node_unsafe(middle, proc);
  }
  pvector_for_each_digit_unsafe(suffix, proc);
}

#define PV_CURSOR_DONE 0
#define PV_CURSOR_SINGLE 1
#define PV_CURSOR_PREFIX 2
#define PV_CURSOR_MIDDLE 3
#define PV_CURSOR_SUFFIX 4

static Scheme_Object *
pvector_cursor_int(int v)
{
  return scheme_make_integer(v);
}

static Scheme_Object *
pvector_node_child(Scheme_Object *node_obj, int index)
{
  if (index == 0) {
    return SCHEME_PVECTOR_NODE_A(node_obj);
  } else if (index == 1) {
    return SCHEME_PVECTOR_NODE_B(node_obj);
  } else {
    return SCHEME_PVECTOR_NODE_C(node_obj);
  }
}

static void
pvector_cursor_set_done(Scheme_PVector_Cursor *cursor)
{
  cursor->segment = PV_CURSOR_DONE;
  cursor->leaf = scheme_false;
  cursor->offset = 0;
  cursor->count = 0;
  cursor->depth = 0;
}

static void
pvector_cursor_set_digit(Scheme_PVector_Cursor *cursor, int segment, Scheme_Object *digit_obj,
                         int reverse)
{
  int count = SCHEME_PVECTOR_DIGIT_COUNT(digit_obj);

  cursor->segment = segment;
  cursor->leaf = digit_obj;
  cursor->offset = reverse ? (count - 1) : 0;
  cursor->count = count;
}

static void
pvector_cursor_set_node_leaf(Scheme_PVector_Cursor *cursor, Scheme_Object *node_obj,
                             int reverse)
{
  int count = SCHEME_PVECTOR_NODE_ARITY(node_obj);

  cursor->segment = PV_CURSOR_MIDDLE;
  cursor->leaf = node_obj;
  cursor->offset = reverse ? (count - 1) : 0;
  cursor->count = count;
}

static void
pvector_cursor_push_frame(Scheme_PVector_Cursor *cursor, Scheme_Object *node_obj,
                          int next_index)
{
  Scheme_Object *stack, *indexes, *next_index_obj;
  int depth;

  stack = cursor->stack;
  indexes = cursor->stack_indexes;
  depth = cursor->depth;
  next_index_obj = pvector_cursor_int(next_index);
  SCHEME_VEC_ELS(stack)[depth] = node_obj;
  SCHEME_VEC_ELS(indexes)[depth] = next_index_obj;
  cursor->depth = depth + 1;
}

static void
pvector_cursor_descend_forward(Scheme_PVector_Cursor *cursor, Scheme_Object *node_obj)
{
  Scheme_Object *node = node_obj;

  while (SCHEME_PVECTOR_NODE_LEVEL(node) > 0) {
    pvector_cursor_push_frame(cursor, node, 1);
    node = SCHEME_PVECTOR_NODE_A(node);
  }

  pvector_cursor_set_node_leaf(cursor, node, 0);
}

static void
pvector_cursor_descend_reverse(Scheme_PVector_Cursor *cursor, Scheme_Object *node_obj)
{
  Scheme_Object *node = node_obj;

  while (SCHEME_PVECTOR_NODE_LEVEL(node) > 0) {
    int arity = SCHEME_PVECTOR_NODE_ARITY(node);
    pvector_cursor_push_frame(cursor, node, arity - 2);
    node = pvector_node_child(node, arity - 1);
  }

  pvector_cursor_set_node_leaf(cursor, node, 1);
}

static int
pvector_cursor_next_middle_forward(Scheme_PVector_Cursor *cursor)
{
  Scheme_Object *stack, *indexes;
  int depth;

  stack = cursor->stack;
  indexes = cursor->stack_indexes;
  depth = cursor->depth;
  while (depth > 0) {
    Scheme_Object *parent, *next_index_obj;
    int next_index, arity;

    parent = SCHEME_VEC_ELS(stack)[depth - 1];
    next_index = SCHEME_INT_VAL(SCHEME_VEC_ELS(indexes)[depth - 1]);
    arity = SCHEME_PVECTOR_NODE_ARITY(parent);
    if (next_index < arity) {
      next_index_obj = pvector_cursor_int(next_index + 1);
      SCHEME_VEC_ELS(indexes)[depth - 1] = next_index_obj;
      cursor->depth = depth;
      pvector_cursor_descend_forward(cursor, pvector_node_child(parent, next_index));
      return 1;
    }
    --depth;
  }

  cursor->depth = 0;
  return 0;
}

static int
pvector_cursor_next_middle_reverse(Scheme_PVector_Cursor *cursor)
{
  Scheme_Object *stack, *indexes;
  int depth;

  stack = cursor->stack;
  indexes = cursor->stack_indexes;
  depth = cursor->depth;
  while (depth > 0) {
    Scheme_Object *parent, *next_index_obj;
    int next_index;

    parent = SCHEME_VEC_ELS(stack)[depth - 1];
    next_index = SCHEME_INT_VAL(SCHEME_VEC_ELS(indexes)[depth - 1]);
    if (next_index >= 0) {
      next_index_obj = pvector_cursor_int(next_index - 1);
      SCHEME_VEC_ELS(indexes)[depth - 1] = next_index_obj;
      cursor->depth = depth;
      pvector_cursor_descend_reverse(cursor, pvector_node_child(parent, next_index));
      return 1;
    }
    --depth;
  }

  cursor->depth = 0;
  return 0;
}

static void
pvector_cursor_advance_forward(Scheme_PVector_Cursor *cursor)
{
  Scheme_Object *pv_obj, *middle;
  int segment;

  pv_obj = cursor->pv;
  segment = cursor->segment;
  if (segment == PV_CURSOR_SINGLE) {
    pvector_cursor_set_done(cursor);
  } else if (segment == PV_CURSOR_PREFIX) {
    middle = SCHEME_PVECTOR_B(pv_obj);
    if (SCHEME_FALSEP(middle)) {
      pvector_cursor_set_digit(cursor, PV_CURSOR_SUFFIX, SCHEME_PVECTOR_C(pv_obj), 0);
    } else {
      cursor->depth = 0;
      pvector_cursor_descend_forward(cursor, middle);
    }
  } else if (segment == PV_CURSOR_MIDDLE) {
    if (!pvector_cursor_next_middle_forward(cursor)) {
      pvector_cursor_set_digit(cursor, PV_CURSOR_SUFFIX, SCHEME_PVECTOR_C(pv_obj), 0);
    }
  } else if (segment == PV_CURSOR_SUFFIX) {
    pvector_cursor_set_done(cursor);
  } else {
    scheme_signal_error("internal error: pvector cursor is already exhausted");
  }
}

static void
pvector_cursor_advance_reverse(Scheme_PVector_Cursor *cursor)
{
  Scheme_Object *pv_obj, *middle;
  int segment;

  pv_obj = cursor->pv;
  segment = cursor->segment;
  if (segment == PV_CURSOR_SINGLE) {
    pvector_cursor_set_done(cursor);
  } else if (segment == PV_CURSOR_SUFFIX) {
    middle = SCHEME_PVECTOR_B(pv_obj);
    if (SCHEME_FALSEP(middle)) {
      pvector_cursor_set_digit(cursor, PV_CURSOR_PREFIX, SCHEME_PVECTOR_A(pv_obj), 1);
    } else {
      cursor->depth = 0;
      pvector_cursor_descend_reverse(cursor, middle);
    }
  } else if (segment == PV_CURSOR_MIDDLE) {
    if (!pvector_cursor_next_middle_reverse(cursor)) {
      pvector_cursor_set_digit(cursor, PV_CURSOR_PREFIX, SCHEME_PVECTOR_A(pv_obj), 1);
    }
  } else if (segment == PV_CURSOR_PREFIX) {
    pvector_cursor_set_done(cursor);
  } else {
    scheme_signal_error("internal error: pvector cursor is already exhausted");
  }
}

static Scheme_Object *
pvector_make_cursor(Scheme_Object *pv_obj, int reverse)
{
  Scheme_PVector_Cursor *cursor;
  Scheme_Object *stack, *indexes, *middle;
  int stack_len = 1;

  if (SCHEME_PVECTOR_SHAPE(pv_obj) == SCHEME_PVECTOR_DEEP) {
    middle = SCHEME_PVECTOR_B(pv_obj);
    if (!SCHEME_FALSEP(middle)) {
      stack_len = SCHEME_PVECTOR_NODE_LEVEL(middle) + 2;
    }
  }

  stack = scheme_make_vector(stack_len, scheme_false);
  indexes = scheme_make_vector(stack_len, scheme_make_integer(0));

  cursor = (Scheme_PVector_Cursor *)scheme_malloc_tagged(sizeof(Scheme_PVector_Cursor));
  cursor->so.type = scheme_pvector_node_type;
  cursor->kind = SCHEME_PVECTOR_NODE_CURSOR;
  cursor->segment = PV_CURSOR_DONE;
  cursor->offset = 0;
  cursor->count = 0;
  cursor->depth = 0;
  cursor->pv = pv_obj;
  cursor->leaf = scheme_false;
  cursor->stack = stack;
  cursor->stack_indexes = indexes;
  cursor->reverse = reverse ? 1 : 0;

  if (SCHEME_PVECTOR_SHAPE(pv_obj) == SCHEME_PVECTOR_EMPTY) {
    pvector_cursor_set_done(cursor);
  } else if (SCHEME_PVECTOR_SHAPE(pv_obj) == SCHEME_PVECTOR_SINGLE) {
    cursor->segment = PV_CURSOR_SINGLE;
    cursor->leaf = pv_obj;
    cursor->offset = 0;
    cursor->count = 1;
  } else if (reverse) {
    pvector_cursor_set_digit(cursor, PV_CURSOR_SUFFIX, SCHEME_PVECTOR_C(pv_obj), 1);
  } else {
    pvector_cursor_set_digit(cursor, PV_CURSOR_PREFIX, SCHEME_PVECTOR_A(pv_obj), 0);
  }

  return (Scheme_Object *)cursor;
}

static Scheme_Object *
pvector_cursor_next_unsafe(Scheme_PVector_Cursor *cursor)
{
  Scheme_Object *leaf, *value;
  int segment, offset, count, done, reverse;

  segment = cursor->segment;
  if (segment == PV_CURSOR_DONE) {
    scheme_signal_error("internal error: pvector cursor is exhausted");
    return NULL;
  }

  leaf = cursor->leaf;
  offset = cursor->offset;
  count = cursor->count;
  reverse = cursor->reverse;

  if (segment == PV_CURSOR_SINGLE) {
    value = SCHEME_PVECTOR_A(leaf);
  } else if ((segment == PV_CURSOR_PREFIX) || (segment == PV_CURSOR_SUFFIX)) {
    value = SCHEME_PVECTOR_DIGIT_ELS(leaf)[offset];
  } else {
    value = pvector_node_child(leaf, offset);
  }

  done = reverse ? (offset == 0) : (offset + 1 == count);
  if (done) {
    if (reverse) {
      pvector_cursor_advance_reverse(cursor);
    } else {
      pvector_cursor_advance_forward(cursor);
    }
  } else {
    cursor->offset = reverse ? (offset - 1) : (offset + 1);
  }

  return value;
}

static Scheme_Object *
core_pvector_cursor_start_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv_obj;

  pv_obj = checked_pvector("core-pvector-cursor-start", argc, argv);
  return pvector_make_cursor(pv_obj, SCHEME_TRUEP(argv[1]));
}

static Scheme_Object *
core_pvector_cursor_next_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *cursor_obj = argv[0];
  Scheme_PVector_Cursor *cursor;

  if (!SCHEME_PVECTOR_CURSORP(cursor_obj)) {
    scheme_wrong_contract("core-pvector-cursor-next", "pvector cursor?", 0, argc, argv);
    return NULL;
  }

  cursor = (Scheme_PVector_Cursor *)cursor_obj;
  if (!SCHEME_PVECTORP(cursor->pv)) {
    scheme_wrong_contract("core-pvector-cursor-next", "pvector cursor?", 0, argc, argv);
    return NULL;
  }

  return pvector_cursor_next_unsafe(cursor);
}

static Scheme_Object *
core_pvector_cons_left_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv_obj;

  pv_obj = checked_pvector("core-pvector-cons-left", argc, argv);
  return pvector_cons_left_unsafe(pv_obj, argv[1]);
}

static Scheme_Object *
core_pvector_cons_right_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv_obj;

  pv_obj = checked_pvector("core-pvector-cons-right", argc, argv);
  return pvector_cons_right_unsafe(pv_obj, argv[1]);
}

Scheme_Object *
scheme_pvector_cons_left(Scheme_Object *pv, Scheme_Object *value)
{
  pv = checked_pvector_value("core-pvector-cons-left", pv);
  return pvector_cons_left_unsafe(pv, value);
}

Scheme_Object *
scheme_pvector_cons_right(Scheme_Object *pv, Scheme_Object *value)
{
  pv = checked_pvector_value("core-pvector-cons-right", pv);
  return pvector_cons_right_unsafe(pv, value);
}

static void
pvector_pop_left_unsafe(Scheme_Object *pv_obj,
                        Scheme_Object **out_value,
                        Scheme_Object **out_rest)
{
  Scheme_Object *value, *prefix, *middle, *suffix, *leaf, *rest;
  Scheme_PVector *pv;
  Scheme_PVector_Digit *old_prefix, *old_suffix;

  pv = (Scheme_PVector *)pv_obj;

  if (pv->shape == SCHEME_PVECTOR_EMPTY) {
    scheme_signal_error("core-pvector-pop-left: empty pvector");
    return;
  } else if (pv->shape == SCHEME_PVECTOR_SINGLE) {
    *out_value = pv->a;
    *out_rest = core_pvector_empty;
    return;
  }

  old_prefix = (Scheme_PVector_Digit *)pv->a;
  value = old_prefix->els[0];
  if (old_prefix->count > 1) {
    prefix = make_digit_without_first(pv->a);
    rest = make_deep_pvector(pv->length - 1, prefix, pv->b, pv->c,
                             old_prefix->count - 1, pv->suffix_len);
  } else if (!SCHEME_FALSEP(pv->b)) {
    leaf = NULL;
    middle = NULL;
    node_tree_pop_left_leaf(pv->b, &leaf, &middle);
    prefix = make_digit_from_leaf_node(leaf);
    rest = make_deep_pvector(pv->length - 1, prefix, middle, pv->c,
                             SCHEME_PVECTOR_NODE_ARITY(leaf), pv->suffix_len);
  } else {
    old_suffix = (Scheme_PVector_Digit *)pv->c;
    if (old_suffix->count == 1) {
      rest = make_single_pvector(old_suffix->els[0]);
    } else {
      prefix = make_digit_from_fields(1, old_suffix->els[0], NULL, NULL, NULL);
      suffix = make_digit_without_first(pv->c);
      rest = make_deep_pvector(pv->length - 1, prefix, scheme_false, suffix,
                               1, old_suffix->count - 1);
    }
  }

  *out_value = value;
  *out_rest = rest;
}

static Scheme_Object *
core_pvector_pop_left_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv_obj, *vals[2];

  pv_obj = checked_pvector("core-pvector-pop-left", argc, argv);
  pvector_pop_left_unsafe(pv_obj, &vals[0], &vals[1]);
  return scheme_values(2, vals);
}

static Scheme_Object *
core_pvector_pop_right_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv_obj;
  Scheme_Object *vals[2];

  pv_obj = checked_pvector("core-pvector-pop-right", argc, argv);
  pvector_pop_right_unsafe(pv_obj, &vals[0], &vals[1]);
  return scheme_values(2, vals);
}

static void
pvector_pop_right_unsafe(Scheme_Object *pv_obj,
                         Scheme_Object **out_value,
                         Scheme_Object **out_rest)
{
  Scheme_Object *value, *prefix, *middle, *suffix, *leaf, *rest;
  Scheme_PVector *pv;
  Scheme_PVector_Digit *old_prefix, *old_suffix;

  pv = (Scheme_PVector *)pv_obj;

  if (pv->shape == SCHEME_PVECTOR_EMPTY) {
    scheme_signal_error("core-pvector-pop-right: empty pvector");
    return;
  } else if (pv->shape == SCHEME_PVECTOR_SINGLE) {
    *out_value = pv->a;
    *out_rest = core_pvector_empty;
    return;
  }

  old_suffix = (Scheme_PVector_Digit *)pv->c;
  value = old_suffix->els[old_suffix->count - 1];
  if (old_suffix->count > 1) {
    suffix = make_digit_without_last(pv->c);
    rest = make_deep_pvector(pv->length - 1, pv->a, pv->b, suffix,
                             pv->prefix_len, old_suffix->count - 1);
  } else if (!SCHEME_FALSEP(pv->b)) {
    leaf = NULL;
    middle = NULL;
    node_tree_pop_right_leaf(pv->b, &leaf, &middle);
    suffix = make_digit_from_leaf_node(leaf);
    rest = make_deep_pvector(pv->length - 1, pv->a, middle, suffix,
                             pv->prefix_len, SCHEME_PVECTOR_NODE_ARITY(leaf));
  } else {
    old_prefix = (Scheme_PVector_Digit *)pv->a;
    if (old_prefix->count == 1) {
      rest = make_single_pvector(old_prefix->els[0]);
    } else {
      prefix = make_digit_without_last(pv->a);
      suffix = make_digit_from_fields(1, old_prefix->els[old_prefix->count - 1], NULL, NULL, NULL);
      rest = make_deep_pvector(pv->length - 1, prefix, scheme_false, suffix,
                               old_prefix->count - 1, 1);
    }
  }

  *out_value = value;
  *out_rest = rest;
}

static Scheme_Object *
core_pvector_append_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *left_obj, *right_obj;

  left_obj = checked_pvector("core-pvector-append", argc, argv);
  if (!SCHEME_PVECTORP(argv[1])) {
    scheme_wrong_contract("core-pvector-append", "pvector?", 1, argc, argv);
    return NULL;
  }
  right_obj = argv[1];

  return pvector_append_unsafe(left_obj, right_obj);
}

static Scheme_Object *
core_pvector_map_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv_obj, *proc;

  pv_obj = checked_pvector("core-pvector-map", argc, argv);
  proc = argv[1];

  if (SAME_OBJ(proc, scheme_values_proc)) {
    return pv_obj;
  } else if (SAME_OBJ(proc, scheme_void_proc)) {
    return pvector_constant_map_unsafe(pv_obj, scheme_void);
  }

  scheme_check_proc_arity("core-pvector-map", 1, 1, argc, argv);
  return pvector_map_unsafe(pv_obj, proc);
}

static Scheme_Object *
core_pvector_for_each_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv_obj, *proc;

  pv_obj = checked_pvector("core-pvector-for-each", argc, argv);
  proc = argv[1];

  if (SAME_OBJ(proc, scheme_values_proc)
      || SAME_OBJ(proc, scheme_void_proc)) {
    return scheme_void;
  }

  scheme_check_proc_arity("core-pvector-for-each", 1, 1, argc, argv);
  pvector_for_each_unsafe(pv_obj, proc);
  return scheme_void;
}

static Scheme_Object *
core_pvector_split_at_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv_obj, *vals[2];
  intptr_t pos;
  int too_large;

  pos = checked_pvector_index_contract("core-pvector-split-at", argc, argv, 1, &too_large);
  pv_obj = checked_pvector("core-pvector-split-at", argc, argv);
  pos = checked_pvector_position_after_contract("core-pvector-split-at", 1, argc, argv,
                                                pv_obj, pos, too_large);

  pvector_split_at_unsafe(pv_obj, pos, &vals[0], &vals[1]);
  return scheme_values(2, vals);
}

static Scheme_Object *
core_pvector_split_at_right_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv_obj, *vals[2];
  Scheme_Object *left, *right;
  intptr_t pos, len, split_pos;
  int too_large;

  pos = checked_pvector_index_contract("core-pvector-split-at-right", argc, argv, 1, &too_large);
  pv_obj = checked_pvector("core-pvector-split-at-right", argc, argv);
  pos = checked_pvector_position_after_contract("core-pvector-split-at-right", 1, argc, argv,
                                                pv_obj, pos, too_large);
  len = SCHEME_PVECTOR_LENGTH(pv_obj);
  split_pos = len - pos;

  pvector_split_at_unsafe(pv_obj, split_pos, &left, &right);
  vals[0] = right;
  vals[1] = left;
  return scheme_values(2, vals);
}

static Scheme_Object *
core_pvector_split_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv_obj, *right, *rest, *vals[3];
  Scheme_Object *prefix, *middle, *suffix;
  Scheme_Object *prefix_rest, *suffix_part;
  intptr_t index, len, prefix_len, suffix_len, suffix_start, suffix_index;
  int too_large;

  index = checked_pvector_index_contract("core-pvector-split", argc, argv, 1, &too_large);
  pv_obj = checked_pvector("core-pvector-split", argc, argv);
  index = checked_pvector_index_after_contract("core-pvector-split", argc, argv, 1,
                                               pv_obj, index, too_large);
  len = SCHEME_PVECTOR_LENGTH(pv_obj);

  if (index == 0) {
    vals[0] = core_pvector_empty;
    pvector_pop_left_unsafe(pv_obj, &vals[1], &vals[2]);
    return scheme_values(3, vals);
  } else if (index == (len - 1)) {
    pvector_pop_right_unsafe(pv_obj, &vals[1], &vals[0]);
    vals[2] = core_pvector_empty;
    return scheme_values(3, vals);
  } else if (SCHEME_PVECTOR_SHAPE(pv_obj) == SCHEME_PVECTOR_DEEP) {
    prefix = SCHEME_PVECTOR_A(pv_obj);
    middle = SCHEME_PVECTOR_B(pv_obj);
    suffix = SCHEME_PVECTOR_C(pv_obj);
    prefix_len = SCHEME_PVECTOR_PREFIX_LEN(pv_obj);
    suffix_len = SCHEME_PVECTOR_SUFFIX_LEN(pv_obj);
    suffix_start = len - suffix_len;

    if (index < prefix_len) {
      vals[0] = pvector_digit_range_unsafe(prefix, 0, (int)index);
      vals[1] = SCHEME_PVECTOR_DIGIT_ELS(prefix)[index];
      if ((index + 1) < prefix_len) {
        prefix_rest = make_digit_slice_unsafe(prefix,
                                              (int)(index + 1),
                                              (int)prefix_len);
        vals[2] = make_deep_pvector(len - index - 1,
                                    prefix_rest,
                                    middle,
                                    suffix,
                                    (int)(prefix_len - index - 1),
                                    (int)suffix_len);
      } else {
        vals[2] = pvector_from_middle_suffix_digit_unsafe(middle,
                                                          suffix,
                                                          (int)suffix_len);
      }
      return scheme_values(3, vals);
    } else if (index >= suffix_start) {
      suffix_index = index - suffix_start;
      vals[1] = SCHEME_PVECTOR_DIGIT_ELS(suffix)[suffix_index];
      vals[2] = pvector_digit_range_unsafe(suffix,
                                           (int)(suffix_index + 1),
                                           (int)suffix_len);
      if (suffix_index > 0) {
        suffix_part = make_digit_slice_unsafe(suffix,
                                              0,
                                              (int)suffix_index);
        vals[0] = make_deep_pvector(index,
                                    prefix,
                                    middle,
                                    suffix_part,
                                    (int)prefix_len,
                                    (int)suffix_index);
      } else {
        vals[0] = pvector_from_prefix_middle_digit_unsafe(prefix,
                                                          (int)prefix_len,
                                                          middle);
      }
      return scheme_values(3, vals);
    } else if (!SCHEME_FALSEP(middle)) {
      pvector_split_middle_unsafe(prefix,
                                  (int)prefix_len,
                                  middle,
                                  suffix,
                                  (int)suffix_len,
                                  index - prefix_len,
                                  &vals[0],
                                  &vals[1],
                                  &vals[2]);
      return scheme_values(3, vals);
    }
  }

  pvector_split_at_unsafe(pv_obj, index, &vals[0], &right);
  pvector_pop_left_unsafe(right, &vals[1], &rest);
  vals[2] = rest;
  return scheme_values(3, vals);
}

static Scheme_Object *
core_pvector_insert_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv_obj, *left, *right;
  Scheme_Object *prefix, *middle, *suffix;
  intptr_t index, len, prefix_len, suffix_len, suffix_start, suffix_index;
  int too_large;

  index = checked_pvector_index_contract("core-pvector-insert", argc, argv, 1, &too_large);
  pv_obj = checked_pvector("core-pvector-insert", argc, argv);
  index = checked_pvector_position_after_contract("core-pvector-insert", 1, argc, argv,
                                                  pv_obj, index, too_large);
  len = SCHEME_PVECTOR_LENGTH(pv_obj);

  if (index == 0) {
    return pvector_cons_left_unsafe(pv_obj, argv[2]);
  } else if (index == len) {
    return pvector_cons_right_unsafe(pv_obj, argv[2]);
  } else if (SCHEME_PVECTOR_SHAPE(pv_obj) == SCHEME_PVECTOR_DEEP) {
    prefix = SCHEME_PVECTOR_A(pv_obj);
    prefix_len = SCHEME_PVECTOR_PREFIX_LEN(pv_obj);

    if ((index <= prefix_len) && (prefix_len < 4)) {
      middle = SCHEME_PVECTOR_B(pv_obj);
      suffix = SCHEME_PVECTOR_C(pv_obj);
      suffix_len = SCHEME_PVECTOR_SUFFIX_LEN(pv_obj);
      return make_deep_pvector(len + 1,
                               make_digit_with_insert_unsafe(prefix,
                                                             (int)index,
                                                             argv[2]),
                               middle,
                               suffix,
                               (int)(prefix_len + 1),
                               (int)suffix_len);
    }

    suffix_len = SCHEME_PVECTOR_SUFFIX_LEN(pv_obj);
    suffix_start = len - suffix_len;
    if ((index >= suffix_start) && (suffix_len < 4)) {
      suffix = SCHEME_PVECTOR_C(pv_obj);
      suffix_index = index - suffix_start;
      return make_deep_pvector(len + 1,
                               prefix,
                               SCHEME_PVECTOR_B(pv_obj),
                               make_digit_with_insert_unsafe(suffix,
                                                             (int)suffix_index,
                                                             argv[2]),
                               (int)prefix_len,
                               (int)(suffix_len + 1));
    }

    middle = SCHEME_PVECTOR_B(pv_obj);
    if (!SCHEME_FALSEP(middle)
        && (index >= prefix_len)
        && (index <= suffix_start)) {
      suffix = SCHEME_PVECTOR_C(pv_obj);
      return pvector_insert_middle_unsafe(prefix,
                                          (int)prefix_len,
                                          middle,
                                          suffix,
                                          (int)suffix_len,
                                          index - prefix_len,
                                          argv[2]);
    }
  }

  pvector_split_at_unsafe(pv_obj, index, &left, &right);
  return pvector_insert_between_unsafe(left, argv[2], right);
}

static Scheme_Object *
core_pvector_delete_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv_obj, *left, *right, *vals[2];
  Scheme_Object *prefix, *middle, *suffix;
  intptr_t index, len, prefix_len, suffix_len, suffix_start, suffix_index;
  int too_large;

  index = checked_pvector_index_contract("core-pvector-delete", argc, argv, 1, &too_large);
  pv_obj = checked_pvector("core-pvector-delete", argc, argv);
  index = checked_pvector_index_after_contract("core-pvector-delete", argc, argv, 1,
                                               pv_obj, index, too_large);
  len = SCHEME_PVECTOR_LENGTH(pv_obj);

  if (index == 0) {
    pvector_pop_left_unsafe(pv_obj, &vals[1], &vals[0]);
    return scheme_values(2, vals);
  } else if (index == (len - 1)) {
    pvector_pop_right_unsafe(pv_obj, &vals[1], &vals[0]);
    return scheme_values(2, vals);
  } else if (SCHEME_PVECTOR_SHAPE(pv_obj) == SCHEME_PVECTOR_DEEP) {
    prefix = SCHEME_PVECTOR_A(pv_obj);
    prefix_len = SCHEME_PVECTOR_PREFIX_LEN(pv_obj);

    if (index < prefix_len) {
      middle = SCHEME_PVECTOR_B(pv_obj);
      suffix = SCHEME_PVECTOR_C(pv_obj);
      suffix_len = SCHEME_PVECTOR_SUFFIX_LEN(pv_obj);
      vals[1] = SCHEME_PVECTOR_DIGIT_ELS(prefix)[index];
      vals[0] = make_deep_pvector(len - 1,
                                   make_digit_without_index_unsafe(prefix,
                                                                   (int)index),
                                   middle,
                                   suffix,
                                   (int)(prefix_len - 1),
                                   (int)suffix_len);
      return scheme_values(2, vals);
    }

    suffix_len = SCHEME_PVECTOR_SUFFIX_LEN(pv_obj);
    suffix_start = len - suffix_len;
    if (index >= suffix_start) {
      suffix = SCHEME_PVECTOR_C(pv_obj);
      suffix_index = index - suffix_start;
      vals[1] = SCHEME_PVECTOR_DIGIT_ELS(suffix)[suffix_index];
      vals[0] = make_deep_pvector(len - 1,
                                   prefix,
                                   SCHEME_PVECTOR_B(pv_obj),
                                   make_digit_without_index_unsafe(suffix,
                                                                   (int)suffix_index),
                                   (int)prefix_len,
                                   (int)(suffix_len - 1));
      return scheme_values(2, vals);
    }

    middle = SCHEME_PVECTOR_B(pv_obj);
    if (!SCHEME_FALSEP(middle)) {
      suffix = SCHEME_PVECTOR_C(pv_obj);
      vals[0] = pvector_delete_middle_unsafe(prefix,
                                             (int)prefix_len,
                                             middle,
                                             suffix,
                                             (int)suffix_len,
                                             index - prefix_len,
                                             &vals[1]);
      return scheme_values(2, vals);
    }
  }

  pvector_split_at_unsafe(pv_obj, index, &left, &right);
  vals[0] = pvector_append_after_pop_left_unsafe(left, right, &vals[1]);
  return scheme_values(2, vals);
}

static Scheme_Object *
core_pvector_take_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv_obj;
  intptr_t pos;
  int too_large;

  pos = checked_pvector_index_contract("core-pvector-take", argc, argv, 1, &too_large);
  pv_obj = checked_pvector("core-pvector-take", argc, argv);
  pos = checked_pvector_position_after_contract("core-pvector-take", 1, argc, argv,
                                                pv_obj, pos, too_large);
  return pvector_take_unsafe(pv_obj, pos);
}

static Scheme_Object *
core_pvector_drop_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv_obj;
  intptr_t pos;
  int too_large;

  pos = checked_pvector_index_contract("core-pvector-drop", argc, argv, 1, &too_large);
  pv_obj = checked_pvector("core-pvector-drop", argc, argv);
  pos = checked_pvector_position_after_contract("core-pvector-drop", 1, argc, argv,
                                                pv_obj, pos, too_large);
  return pvector_drop_unsafe(pv_obj, pos);
}

static Scheme_Object *
core_pvector_take_right_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv_obj;
  intptr_t pos, len;
  int too_large;

  pos = checked_pvector_index_contract("core-pvector-take-right", argc, argv, 1, &too_large);
  pv_obj = checked_pvector("core-pvector-take-right", argc, argv);
  pos = checked_pvector_position_after_contract("core-pvector-take-right", 1, argc, argv,
                                                pv_obj, pos, too_large);
  len = SCHEME_PVECTOR_LENGTH(pv_obj);
  return pvector_drop_unsafe(pv_obj, len - pos);
}

static Scheme_Object *
core_pvector_drop_right_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv_obj;
  intptr_t pos, len;
  int too_large;

  pos = checked_pvector_index_contract("core-pvector-drop-right", argc, argv, 1, &too_large);
  pv_obj = checked_pvector("core-pvector-drop-right", argc, argv);
  pos = checked_pvector_position_after_contract("core-pvector-drop-right", 1, argc, argv,
                                                pv_obj, pos, too_large);
  len = SCHEME_PVECTOR_LENGTH(pv_obj);
  return pvector_take_unsafe(pv_obj, len - pos);
}

static Scheme_Object *
core_pvector_copy_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv_obj;
  intptr_t len, start, end;
  int start_too_large, end_too_large;

  start = checked_pvector_index_contract("core-pvector-copy", argc, argv, 1,
                                         &start_too_large);
  end = checked_pvector_index_contract("core-pvector-copy", argc, argv, 2,
                                       &end_too_large);
  pv_obj = checked_pvector("core-pvector-copy", argc, argv);
  len = SCHEME_PVECTOR_LENGTH(pv_obj);
  if (start_too_large || (start > len)) {
    scheme_out_of_range("core-pvector-copy", "pvector", "starting ",
                        argv[1], pv_obj, 0, len);
  }
  if (end_too_large || (end < start) || (end > len)) {
    scheme_out_of_range("core-pvector-copy", "pvector", "ending ",
                        argv[2], pv_obj, start, len);
  }
  return pvector_copy_range_unsafe(pv_obj, start, end);
}

static Scheme_Object *
pvector_view_left_checked(const char *who, Scheme_Object *pv)
{
  pv = checked_pvector_value(who, pv);
  if (SCHEME_PVECTOR_LENGTH(pv) == 0) {
    scheme_signal_error("%s: empty pvector", who);
    return NULL;
  }

  return pvector_view_left_unsafe(pv);
}

static Scheme_Object *
pvector_view_right_checked(const char *who, Scheme_Object *pv)
{
  intptr_t len;

  pv = checked_pvector_value(who, pv);
  len = SCHEME_PVECTOR_LENGTH(pv);
  if (len == 0) {
    scheme_signal_error("%s: empty pvector", who);
    return NULL;
  }

  return pvector_view_right_unsafe(pv);
}

static Scheme_Object *
core_pvector_view_left(int argc, Scheme_Object *argv[])
{
  return pvector_view_left_checked("core-pvector-view-left", argv[0]);
}

static Scheme_Object *
core_pvector_view_right(int argc, Scheme_Object *argv[])
{
  return pvector_view_right_checked("core-pvector-view-right", argv[0]);
}

Scheme_Object *
scheme_pvector_view_left(Scheme_Object *pv)
{
  return pvector_view_left_checked("core-pvector-view-left", pv);
}

Scheme_Object *
scheme_pvector_view_right(Scheme_Object *pv)
{
  return pvector_view_right_checked("core-pvector-view-right", pv);
}

void
scheme_init_pvector(Scheme_Startup_Env *env)
{
  Scheme_PVector *empty;
  Scheme_Object *p;

  REGISTER_SO(core_pvector_empty);

  if (!core_pvector_empty) {
    empty = (Scheme_PVector *)scheme_malloc_eternal_tagged(sizeof(Scheme_PVector));
    empty->iso.so.type = scheme_pvector_type;
    empty->length = 0;
    empty->shape = SCHEME_PVECTOR_EMPTY;
    empty->prefix_len = 0;
    empty->suffix_len = 0;
    empty->reserved = 0;
    empty->a = NULL;
    empty->b = NULL;
    empty->c = NULL;
    empty->d = NULL;
    core_pvector_empty = (Scheme_Object *)empty;
    scheme_pvector_empty = core_pvector_empty;
  } else {
    scheme_pvector_empty = core_pvector_empty;
  }

  scheme_set_type_equality(scheme_pvector_type,
                           pvector_equal,
                           pvector_hash1,
                           pvector_hash2);
  scheme_set_type_printer(scheme_pvector_type, pvector_print);

  p = scheme_make_folding_prim(core_pvector_p, "core-pvector?", 1, 1, 1);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_UNARY_INLINED
                                                            | SCHEME_PRIM_IS_OMITABLE
                                                            | SCHEME_PRIM_PRODUCES_BOOL);
  scheme_addto_prim_instance("core-pvector?", p, env);

  p = scheme_make_immed_prim(core_pvector_empty_prim, "core-pvector-empty", 0, 0);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_NARY_INLINED
                                                            | SCHEME_PRIM_IS_OMITABLE);
  scheme_addto_prim_instance("core-pvector-empty", p, env);

  p = scheme_make_folding_prim(core_pvector_empty_p, "core-pvector-empty?", 1, 1, 1);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_UNARY_INLINED
                                                            | SCHEME_PRIM_IS_OMITABLE
                                                            | SCHEME_PRIM_PRODUCES_BOOL);
  scheme_addto_prim_instance("core-pvector-empty?", p, env);

  p = scheme_make_folding_prim(core_pvector_length_prim, "core-pvector-length", 1, 1, 1);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_UNARY_INLINED
                                                            | SCHEME_PRIM_PRODUCES_FIXNUM);
  scheme_addto_prim_instance("core-pvector-length", p, env);

  scheme_addto_prim_instance("core-pvector-shape-stats",
                             scheme_make_immed_prim(core_pvector_shape_stats,
                                                    "core-pvector-shape-stats",
                                                    1, 1),
                             env);
  scheme_addto_prim_instance("core-vector->pvector",
                             scheme_make_immed_prim(core_vector_to_pvector,
                                                    "core-vector->pvector",
                                                    1, 1),
                             env);
  scheme_addto_prim_instance("core-immutable-vector->pvector",
                             scheme_make_immed_prim(core_immutable_vector_to_pvector,
                                                    "core-immutable-vector->pvector",
                                                    1, 1),
                             env);
  scheme_addto_prim_instance("core-fresh-vector->pvector",
                             scheme_make_immed_prim(core_fresh_vector_to_pvector,
                                                    "core-fresh-vector->pvector",
                                                    1, 1),
                             env);
  scheme_addto_prim_instance("core-list->pvector",
                             scheme_make_immed_prim(core_list_to_pvector,
                                                    "core-list->pvector",
                                                    1, 1),
                             env);
  p = scheme_make_immed_prim(core_make_single_pvector,
                             "core-make-single-pvector",
                             1, 1);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_UNARY_INLINED
                                                            | SCHEME_PRIM_IS_OMITABLE_ALLOCATION);
  scheme_addto_prim_instance("core-make-single-pvector", p, env);

  p = scheme_make_immed_prim(core_make_deep2_pvector,
                             "core-make-deep2-pvector",
                             2, 2);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_BINARY_INLINED
                                                            | SCHEME_PRIM_IS_OMITABLE_ALLOCATION);
  scheme_addto_prim_instance("core-make-deep2-pvector", p, env);

  p = scheme_make_immed_prim(core_make_deep3_pvector,
                             "core-make-deep3-pvector",
                             3, 3);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_NARY_INLINED
                                                            | SCHEME_PRIM_IS_OMITABLE_ALLOCATION);
  scheme_addto_prim_instance("core-make-deep3-pvector", p, env);

  p = scheme_make_immed_prim(core_make_deep4_pvector,
                             "core-make-deep4-pvector",
                             4, 4);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_NARY_INLINED
                                                            | SCHEME_PRIM_IS_OMITABLE_ALLOCATION);
  scheme_addto_prim_instance("core-make-deep4-pvector", p, env);
  scheme_addto_prim_instance("core-make-pvector",
                             scheme_make_immed_prim(core_make_pvector,
                                                    "core-make-pvector",
                                                    2, 2),
                             env);
  scheme_addto_prim_instance("core-pvector->vector",
                             scheme_make_immed_prim(core_pvector_to_vector,
                                                    "core-pvector->vector",
                                                    1, 1),
                             env);
  scheme_addto_prim_instance("core-pvector->list",
                             scheme_make_immed_prim(core_pvector_to_list,
                                                    "core-pvector->list",
                                                    1, 1),
                             env);
  p = scheme_make_noncm_prim(core_pvector_ref_prim,
                             "core-pvector-ref",
                             2, 2);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_BINARY_INLINED);
  scheme_addto_prim_instance("core-pvector-ref", p, env);
  p = scheme_make_immed_prim(core_unsafe_pvector_length_prim,
                             "core-unsafe-pvector-length",
                             1, 1);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_UNSAFE_FUNCTIONAL
                                                            | SCHEME_PRIM_IS_UNARY_INLINED
                                                            | SCHEME_PRIM_PRODUCES_FIXNUM);
  scheme_addto_prim_instance("core-unsafe-pvector-length", p, env);

  p = scheme_make_immed_prim(core_unsafe_pvector_ref_prim,
                             "core-unsafe-pvector-ref",
                             2, 2);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_UNSAFE_FUNCTIONAL
                                                            | SCHEME_PRIM_IS_BINARY_INLINED);
  scheme_addto_prim_instance("core-unsafe-pvector-ref", p, env);

  p = scheme_make_immed_prim(core_unsafe_pvector_view_left_prim,
                             "core-unsafe-pvector-view-left",
                             1, 1);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_UNSAFE_FUNCTIONAL
                                                            | SCHEME_PRIM_IS_UNARY_INLINED);
  scheme_addto_prim_instance("core-unsafe-pvector-view-left", p, env);

  p = scheme_make_immed_prim(core_unsafe_pvector_view_right_prim,
                             "core-unsafe-pvector-view-right",
                             1, 1);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_UNSAFE_FUNCTIONAL
                                                            | SCHEME_PRIM_IS_UNARY_INLINED);
  scheme_addto_prim_instance("core-unsafe-pvector-view-right", p, env);

  p = scheme_make_immed_prim(core_unsafe_pvector_view_left_prim,
                             "core-unsafe-pvector-first",
                             1, 1);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_UNSAFE_FUNCTIONAL
                                                            | SCHEME_PRIM_IS_UNARY_INLINED);
  scheme_addto_prim_instance("core-unsafe-pvector-first", p, env);

  p = scheme_make_immed_prim(core_unsafe_pvector_view_right_prim,
                             "core-unsafe-pvector-last",
                             1, 1);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_UNSAFE_FUNCTIONAL
                                                            | SCHEME_PRIM_IS_UNARY_INLINED);
  scheme_addto_prim_instance("core-unsafe-pvector-last", p, env);

  scheme_addto_prim_instance("core-pvector-set",
                             scheme_make_noncm_prim(core_pvector_set_prim,
                                                    "core-pvector-set",
                                                    3, 3),
                             env);
  p = scheme_make_noncm_prim(core_pvector_cons_left_prim,
                             "core-pvector-cons-left",
                             2, 2);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_BINARY_INLINED);
  scheme_addto_prim_instance("core-pvector-cons-left", p, env);

  p = scheme_make_noncm_prim(core_pvector_cons_right_prim,
                             "core-pvector-cons-right",
                             2, 2);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_BINARY_INLINED);
  scheme_addto_prim_instance("core-pvector-cons-right", p, env);
  scheme_addto_prim_instance("core-pvector-pop-left",
                             scheme_make_noncm_prim(core_pvector_pop_left_prim,
                                                    "core-pvector-pop-left",
                                                    1, 1),
                             env);
  scheme_addto_prim_instance("core-pvector-pop-right",
                             scheme_make_noncm_prim(core_pvector_pop_right_prim,
                                                    "core-pvector-pop-right",
                                                    1, 1),
                             env);
  scheme_addto_prim_instance("core-pvector-append",
                             scheme_make_noncm_prim(core_pvector_append_prim,
                                                    "core-pvector-append",
                                                    2, 2),
                             env);
  scheme_addto_prim_instance("core-pvector-map",
                             scheme_make_noncm_prim(core_pvector_map_prim,
                                                    "core-pvector-map",
                                                    2, 2),
                             env);
  scheme_addto_prim_instance("core-pvector-for-each",
                             scheme_make_noncm_prim(core_pvector_for_each_prim,
                                                    "core-pvector-for-each",
                                                    2, 2),
                             env);
  scheme_addto_prim_instance("core-pvector-split-at",
                             scheme_make_noncm_prim(core_pvector_split_at_prim,
                                                    "core-pvector-split-at",
                                                    2, 2),
                             env);
  scheme_addto_prim_instance("core-pvector-split-at-right",
                             scheme_make_noncm_prim(core_pvector_split_at_right_prim,
                                                    "core-pvector-split-at-right",
                                                    2, 2),
                             env);
  scheme_addto_prim_instance("core-pvector-split",
                             scheme_make_noncm_prim(core_pvector_split_prim,
                                                    "core-pvector-split",
                                                    2, 2),
                             env);
  scheme_addto_prim_instance("core-pvector-insert",
                             scheme_make_noncm_prim(core_pvector_insert_prim,
                                                    "core-pvector-insert",
                                                    3, 3),
                             env);
  scheme_addto_prim_instance("core-pvector-delete",
                             scheme_make_noncm_prim(core_pvector_delete_prim,
                                                    "core-pvector-delete",
                                                    2, 2),
                             env);
  scheme_addto_prim_instance("core-pvector-take",
                             scheme_make_noncm_prim(core_pvector_take_prim,
                                                    "core-pvector-take",
                                                    2, 2),
                             env);
  scheme_addto_prim_instance("core-pvector-drop",
                             scheme_make_noncm_prim(core_pvector_drop_prim,
                                                    "core-pvector-drop",
                                                    2, 2),
                             env);
  scheme_addto_prim_instance("core-pvector-take-right",
                             scheme_make_noncm_prim(core_pvector_take_right_prim,
                                                    "core-pvector-take-right",
                                                    2, 2),
                             env);
  scheme_addto_prim_instance("core-pvector-drop-right",
                             scheme_make_noncm_prim(core_pvector_drop_right_prim,
                                                    "core-pvector-drop-right",
                                                    2, 2),
                             env);
  scheme_addto_prim_instance("core-pvector-copy",
                             scheme_make_noncm_prim(core_pvector_copy_prim,
                                                    "core-pvector-copy",
                                                    3, 3),
                             env);
  p = scheme_make_immed_prim(core_pvector_view_left,
                             "core-pvector-view-left",
                             1, 1);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_UNARY_INLINED);
  scheme_addto_prim_instance("core-pvector-view-left", p, env);

  p = scheme_make_immed_prim(core_pvector_view_right,
                             "core-pvector-view-right",
                             1, 1);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_UNARY_INLINED);
  scheme_addto_prim_instance("core-pvector-view-right", p, env);
}

void
scheme_init_pvector_late(Scheme_Startup_Env *env)
{
  /* Append new kernel primitives after existing primitives so compiled
     startup indices for older names stay stable. */
  scheme_addto_prim_instance("core-pvector-cursor-start",
                             scheme_make_immed_prim(core_pvector_cursor_start_prim,
                                                    "core-pvector-cursor-start",
                                                    2, 2),
                             env);

  scheme_addto_prim_instance("core-pvector-cursor-next",
                             scheme_make_immed_prim(core_pvector_cursor_next_prim,
                                                    "core-pvector-cursor-next",
                                                    1, 1),
                             env);
}
