#include "schpriv.h"

static Scheme_Object *core_pvector_empty;

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
static Scheme_Object *core_pvector_set_prim(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_view_left(int argc, Scheme_Object *argv[]);
static Scheme_Object *core_pvector_view_right(int argc, Scheme_Object *argv[]);

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
build_node_tree_from_vector(Scheme_Object *vec, intptr_t start,
                            intptr_t count, int level)
{
  Scheme_Object *next_vec;
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
  next_vec = (Scheme_Object *)scheme_make_vector(groups, NULL);
  group_index = 0;
  pos = start;
  remaining = count;

  while (remaining > 0) {
    group = next_group_size(remaining);
    node = make_node_from_vector(vec, pos, group, level);
    SCHEME_VEC_ELS(next_vec)[group_index] = node;
    group_index++;
    pos += group;
    remaining -= group;
  }

  return build_node_tree_from_vector(next_vec, 0, groups, level + 1);
}

static Scheme_Object *
build_node_tree_from_args(Scheme_Object **argv, intptr_t start,
                          intptr_t count, int level)
{
  Scheme_Object *next_vec;
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
  next_vec = (Scheme_Object *)scheme_make_vector(groups, NULL);
  group_index = 0;
  pos = start;
  remaining = count;

  while (remaining > 0) {
    group = next_group_size(remaining);
    node = make_node_from_args(argv, pos, group, level);
    SCHEME_VEC_ELS(next_vec)[group_index] = node;
    group_index++;
    pos += group;
    remaining -= group;
  }

  return build_node_tree_from_vector(next_vec, 0, groups, level + 1);
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
pvector_from_args(int argc, Scheme_Object **argv)
{
  int prefix_len, suffix_len;
  intptr_t middle_len;
  Scheme_Object *prefix, *middle, *suffix;

  if (argc == 0) {
    return core_pvector_empty;
  } else if (argc == 1) {
    return make_single_pvector(argv[0]);
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
  intptr_t len, middle_len;
  int prefix_len, suffix_len;
  Scheme_Object *prefix, *middle, *suffix;

  len = SCHEME_VEC_SIZE(vec);
  if (len == 0) {
    return core_pvector_empty;
  } else if (len == 1) {
    return make_single_pvector(SCHEME_VEC_ELS(vec)[0]);
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
  intptr_t i, len;
  Scheme_Object *vec, *orig;

  orig = list;
  len = scheme_proper_list_length(list);
  if (len < 0) {
    scheme_wrong_contract("core-list->pvector", "list?", 0, 1, &orig);
    return NULL;
  }

  vec = (Scheme_Object *)scheme_make_vector(len, NULL);
  for (i = 0; i < len; i++) {
    SCHEME_VEC_ELS(vec)[i] = SCHEME_CAR(list);
    list = SCHEME_CDR(list);
  }

  return pvector_from_vector(vec);
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
  Scheme_Object *a, *b, *c;
  intptr_t a_measure, b_measure;

  if (node->level == 0) {
    if (index == 0) {
      a = value;
      b = node->b;
      c = node->c;
    } else if (index == 1) {
      a = node->a;
      b = value;
      c = node->c;
    } else if ((node->arity == 3) && (index == 2)) {
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
      a = node_set(node->a, index, value);
      b = node->b;
      c = node->c;
    } else {
      b_measure = pvector_child_measure(node->b);
      index -= a_measure;
      if ((node->arity == 2) || (index < b_measure)) {
        a = node->a;
        b = node_set(node->b, index, value);
        c = node->c;
      } else {
        a = node->a;
        b = node->b;
        c = node_set(node->c, index - b_measure, value);
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

  if (pv->shape == SCHEME_PVECTOR_SINGLE) {
    return pv->a;
  } else if (pv->shape == SCHEME_PVECTOR_DEEP) {
    Scheme_PVector_Digit *prefix = (Scheme_PVector_Digit *)pv->a;
    Scheme_PVector_Digit *suffix = (Scheme_PVector_Digit *)pv->c;
    intptr_t suffix_start = pv->length - suffix->count;

    if (index < prefix->count) {
      return prefix->els[index];
    } else if (index >= suffix_start) {
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

static intptr_t
checked_pvector_index(const char *who, int argc, Scheme_Object **argv,
                      Scheme_Object *pv)
{
  intptr_t len, index;

  len = SCHEME_PVECTOR_LENGTH(pv);
  index = scheme_extract_index(who, 1, argc, argv, len, 0);

  if (index >= len) {
    scheme_out_of_range(who, "pvector", "", argv[1], pv, 0, len - 1);
    return 0;
  }

  return index;
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
  Scheme_Object *vec;

  len = scheme_extract_index("core-make-pvector", 0, argc, argv, -1, 0);
  fill = argv[1];
  vec = (Scheme_Object *)scheme_make_vector(len, fill);
  return pvector_from_vector(vec);
}

static Scheme_Object *
core_pvector_to_vector(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv, *vec, *elem;
  intptr_t len, i;

  pv = checked_pvector("core-pvector->vector", argc, argv);
  len = SCHEME_PVECTOR_LENGTH(pv);
  vec = (Scheme_Object *)scheme_make_vector(len, NULL);

  for (i = 0; i < len; i++) {
    elem = pvector_ref_unsafe(pv, i);
    SCHEME_VEC_ELS(vec)[i] = elem;
  }

  return vec;
}

static Scheme_Object *
core_pvector_to_list(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv, *lst, *elem;
  intptr_t len;

  pv = checked_pvector("core-pvector->list", argc, argv);
  len = SCHEME_PVECTOR_LENGTH(pv);
  lst = scheme_null;

  while (len--) {
    elem = pvector_ref_unsafe(pv, len);
    lst = scheme_make_pair(elem, lst);
  }

  return lst;
}

static Scheme_Object *
core_pvector_ref_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv;
  intptr_t index;

  pv = checked_pvector("core-pvector-ref", argc, argv);
  index = checked_pvector_index("core-pvector-ref", argc, argv, pv);
  return pvector_ref_unsafe(pv, index);
}

static Scheme_Object *
core_pvector_set_prim(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv_obj, *old, *value, *prefix, *middle, *suffix;
  Scheme_PVector *pv;
  intptr_t index, suffix_start;

  pv_obj = checked_pvector("core-pvector-set", argc, argv);
  index = checked_pvector_index("core-pvector-set", argc, argv, pv_obj);
  value = argv[2];
  old = pvector_ref_unsafe(pv_obj, index);
  if (SAME_OBJ(old, value)) {
    return pv_obj;
  }

  pv = (Scheme_PVector *)pv_obj;
  if (pv->shape == SCHEME_PVECTOR_SINGLE) {
    return make_single_pvector(value);
  }

  if (pv->shape != SCHEME_PVECTOR_DEEP) {
    scheme_signal_error("internal error: pvector set reached empty pvector");
    return NULL;
  }

  suffix_start = pv->length - pv->suffix_len;
  if (index < pv->prefix_len) {
    prefix = make_digit_with_replaced(pv->a, (int)index, value);
    return make_deep_pvector(pv->length, prefix, pv->b, pv->c,
                             pv->prefix_len, pv->suffix_len);
  } else if (index >= suffix_start) {
    suffix = make_digit_with_replaced(pv->c, (int)(index - suffix_start), value);
    return make_deep_pvector(pv->length, pv->a, pv->b, suffix,
                             pv->prefix_len, pv->suffix_len);
  } else {
    middle = node_set(pv->b, index - pv->prefix_len, value);
    return make_deep_pvector(pv->length, pv->a, middle, pv->c,
                             pv->prefix_len, pv->suffix_len);
  }
}

static Scheme_Object *
core_pvector_view_left(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv;

  pv = checked_pvector("core-pvector-view-left", argc, argv);
  if (SCHEME_PVECTOR_LENGTH(pv) == 0) {
    scheme_signal_error("core-pvector-view-left: empty pvector");
    return NULL;
  }

  return pvector_ref_unsafe(pv, 0);
}

static Scheme_Object *
core_pvector_view_right(int argc, Scheme_Object *argv[])
{
  Scheme_Object *pv;
  intptr_t len;

  pv = checked_pvector("core-pvector-view-right", argc, argv);
  len = SCHEME_PVECTOR_LENGTH(pv);
  if (len == 0) {
    scheme_signal_error("core-pvector-view-right: empty pvector");
    return NULL;
  }

  return pvector_ref_unsafe(pv, len - 1);
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
  }

  p = scheme_make_folding_prim(core_pvector_p, "core-pvector?", 1, 1, 1);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_OMITABLE
                                                            | SCHEME_PRIM_PRODUCES_BOOL);
  scheme_addto_prim_instance("core-pvector?", p, env);

  p = scheme_make_immed_prim(core_pvector_empty_prim, "core-pvector-empty", 0, 0);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_OMITABLE);
  scheme_addto_prim_instance("core-pvector-empty", p, env);

  p = scheme_make_folding_prim(core_pvector_empty_p, "core-pvector-empty?", 1, 1, 1);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_IS_OMITABLE
                                                            | SCHEME_PRIM_PRODUCES_BOOL);
  scheme_addto_prim_instance("core-pvector-empty?", p, env);

  p = scheme_make_folding_prim(core_pvector_length_prim, "core-pvector-length", 1, 1, 1);
  SCHEME_PRIM_PROC_FLAGS(p) |= scheme_intern_prim_opt_flags(SCHEME_PRIM_PRODUCES_FIXNUM);
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
  scheme_addto_prim_instance("core-make-single-pvector",
                             scheme_make_immed_prim(core_make_single_pvector,
                                                    "core-make-single-pvector",
                                                    1, 1),
                             env);
  scheme_addto_prim_instance("core-make-deep2-pvector",
                             scheme_make_immed_prim(core_make_deep2_pvector,
                                                    "core-make-deep2-pvector",
                                                    2, 2),
                             env);
  scheme_addto_prim_instance("core-make-deep3-pvector",
                             scheme_make_immed_prim(core_make_deep3_pvector,
                                                    "core-make-deep3-pvector",
                                                    3, 3),
                             env);
  scheme_addto_prim_instance("core-make-deep4-pvector",
                             scheme_make_immed_prim(core_make_deep4_pvector,
                                                    "core-make-deep4-pvector",
                                                    4, 4),
                             env);
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
  scheme_addto_prim_instance("core-pvector-ref",
                             scheme_make_noncm_prim(core_pvector_ref_prim,
                                                    "core-pvector-ref",
                                                    2, 2),
                             env);
  scheme_addto_prim_instance("core-pvector-set",
                             scheme_make_noncm_prim(core_pvector_set_prim,
                                                    "core-pvector-set",
                                                    3, 3),
                             env);
  scheme_addto_prim_instance("core-pvector-view-left",
                             scheme_make_immed_prim(core_pvector_view_left,
                                                    "core-pvector-view-left",
                                                    1, 1),
                             env);
  scheme_addto_prim_instance("core-pvector-view-right",
                             scheme_make_immed_prim(core_pvector_view_right,
                                                    "core-pvector-view-right",
                                                    1, 1),
                             env);
}
