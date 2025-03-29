import std/tables {.all.}
import std/[hashes, importutils]

template withValue*[K, V](table: Table[K, V], key: K, value, body: untyped) =
  ## Executes `body` if `key` exists in table. The value of the entry is assigned to `value`.
  ## We are doing some hacky things with the table API here for the sake of speed. This
  ## prevents us from having to recalculate the hash every time, and from creating a copy
  ## of the seq that is being iterated.
  privateAccess(Table)
  var hc: Hash
  var index = rawGet(table, key, hc)
  if index > 0:
    let value {.cursor.} = table.data[index].val
    body
