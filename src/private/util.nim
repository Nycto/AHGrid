import std/tables {.all.}
import std/[hashes, importutils]

iterator listAtKey*[K, V](table: Table[K, seq[V]], key: K): V =
  ## Iterates over the seq found in a table, assuming that key exists. We are doing some hacky things with the
  ## table API here for the sake of speed. This prevents us from having to recalculate the hash every time, and
  ## from creating a copy of the seq that is being iterated.
  privateAccess(Table)
  var hc: Hash
  var index = rawGet(table, key, hc)
  if index > 0:
    for entry in table.data[index].val:
      yield entry
