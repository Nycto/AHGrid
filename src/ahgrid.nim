##
## Spatial index that allows for querying of objects within a radius of a given point
##
## Details about the specifics of this algorithm can be found here:
##
## https://elephantstarballoon.com/post/ahgrid/
##
runnableExamples:
  var grid = newAHGrid[tuple[x, y, width, height: int32]]()

  # The returned handles remove their value from the grid when destroyed,
  # so they must stay alive for as long as the value should remain stored
  let handle1 {.used.} = grid.insert((x: 1'i32, y: 2'i32, width: 3'i32, height: 4'i32))
  let handle2 {.used.} = grid.insert((x: 5'i32, y: 6'i32, width: 7'i32, height: 8'i32))

  for obj in grid.find(3, 4, 10):
    echo "Found object near point: ", obj

import std/[tables, math, strformat, hashes, bitops], private/util

type
  SpatialObject* = concept obj
    ## A value that can be stored in a 2d AHGrid
    obj.x is int32
    obj.y is int32
    obj.width is int32
    obj.height is int32

  GridHandle*[T] = object
    ## A handle for a value that can be stored in an AHGrid -- used to update that value
    obj: T
    key: CellIndex
    grid: AHGrid[T]

  CellIndex = tuple[xBucket, yBucket, scale: int32]

  AHGrid*[T] = ref object ## A 2d spatial index
    maxScale, minScale: int32
    scaleCounts: array[32, int32]
      ## Number of stored objects per scale, indexed by log2 of the scale.
      ## Lets searches skip scales that contain no objects.
    cells: Table[CellIndex, seq[T]]

proc `=copy`[T](a: var GridHandle[T], b: GridHandle[T]) {.error.}

proc remove*[T](grid: AHGrid[T], handle: GridHandle[T])

proc `=destroy`[T](handle: var GridHandle[T]) =
  if handle.grid != nil:
    handle.grid.remove(handle)

proc hash*(x: CellIndex): Hash =
  return !$(hash(x.xBucket) !& hash(x.yBucket) !& hash(x.scale))

proc newAHGrid*[T](
    initialSize: Positive = defaultInitialSize, minCellSize: int32 = 2
): AHGrid[T] =
  ## Create a new AHGrid store
  return AHGrid[T](
    minScale: minCellSize.nextPowerOfTwo.int32,
    maxScale: 0,
    cells: initTable[CellIndex, seq[T]](initialSize),
  )

proc `$`(index: CellIndex): string =
  fmt"{index.xBucket}x{index.yBucket}x{index.scale}"

proc `$`*(grid: AHGrid): string =
  result = "AHGrid("
  for key, values in grid.cells.pairs:
    if values.len > 0:
      result &= fmt"{key}: {values}, "
  result &= ")"

# Values are normalized into cells that fall into the following layout:
#
#               0                   10                  20
# | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | |
# |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
#   |       |       |       |       |       |       |       |       |
#       |               |               |               |               |
#                               |                                 |

proc chooseBucket(coord, scale: int32): int32 =
  ## Normalizes a coordinate onto a line where the only valid values are multiples of `scale`.
  ## This also offsets each coordinate by `scale/2` to ensure that an entity that falls on the edge of
  ## its "best" cell won't fall into the edge on the next cell up
  assert(scale > 0, "Scale must be greater than 0")
  assert(scale.isPowerOfTwo, "Scale must be a power of two")

  let half = scale div 2
  result = floorDiv(coord + half, scale) * scale - half

proc pickCellIndex(grid: AHGrid, x, y, dimen: int32): CellIndex =
  ## Calculates the cell that a square falls into
  ## `x` and `y` are coordinates, `dimen` is the length of the side of the square

  # The largest scale that fits in an int32; anything bigger can't be indexed
  const scaleLimit = 1 shl 30

  let initialScale = dimen.int.nextPowerOfTwo
  assert(initialScale <= scaleLimit, "Object is too large to index: " & $dimen)

  var scale = max(initialScale.int32, grid.minScale)

  while true:
    result =
      (xBucket: x.chooseBucket(scale), yBucket: y.chooseBucket(scale), scale: scale)

    # If the entity fits completely into the cell we've picked, we're done.
    if x + dimen < result.xBucket + scale and y + dimen < result.yBucket + scale:
      break

    # If it doesn't fit, we need to try the next scale up
    assert(scale < scaleLimit, "Object can not be indexed: " & $((x, y, dimen)))
    scale = scale * 2

  # The resulting cell should completely contain the object being stored
  assert(x >= result.xBucket, fmt"{x} >= {result.xBucket}")
  assert(y >= result.yBucket, fmt"{y} >= {result.yBucket}")
  assert(
    x + dimen <= result.xBucket + result.scale,
    fmt"{x} + {dimen} <= {result.xBucket} + {result.scale}",
  )
  assert(
    y + dimen <= result.yBucket + result.scale,
    fmt"{y} + {dimen} <= {result.yBucket} + {result.scale}",
  )

proc pickCellIndex(obj: SpatialObject, grid: AHGrid): CellIndex =
  ## Calculates the cell that an object should be stored in
  pickCellIndex(grid, obj.x, obj.y, max(obj.height, obj.width))

proc insertAtKey[T](grid: AHGrid[T], key: CellIndex, obj: T) =
  ## Inserts a value when the key is already known
  grid.maxScale = max(grid.maxScale, key.scale)
  grid.scaleCounts[key.scale.countTrailingZeroBits] += 1
  grid.cells.mgetOrPut(key, newSeq[T]()).add(obj)

proc insert*[T](grid: AHGrid[T], value: T, space: SpatialObject): GridHandle[T] =
  ## Add a value to this spatial grid. The value is removed from the grid when the returned
  ## handle is destroyed, so the handle must be kept alive for as long as the value should
  ## remain stored.
  let key = space.pickCellIndex(grid)
  insertAtKey(grid, key, value)
  return GridHandle[T](key: key, obj: value, grid: grid)

proc insert*[T: SpatialObject](
    grid: AHGrid[T], value: T
): GridHandle[T] {.inline.} =
  ## Add a value to this spatial grid. The value is removed from the grid when the returned
  ## handle is destroyed, so the handle must be kept alive for as long as the value should
  ## remain stored.
  insert(grid, value, value)

iterator eachScale(grid: AHGrid): int32 =
  ## Yields each scale that contains at least one object
  var scale = grid.minScale
  while scale <= grid.maxScale:
    if grid.scaleCounts[scale.countTrailingZeroBits] > 0:
      yield scale
    scale *= 2

iterator eachCellIndex(x1, y1, x2, y2, scale: int32): CellIndex =
  ## Yields each cell key within a given radius of a point at the given scale
  let (xLow, xHigh) = (chooseBucket(x1, scale), chooseBucket(x2, scale))
  let (yLow, yHigh) = (chooseBucket(y1, scale), chooseBucket(y2, scale))

  for x in countup(xLow, xHigh, scale):
    for y in countup(yLow, yHigh, scale):
      yield (x, y, scale)

iterator find*[T](grid: AHGrid[T], x1, y1, x2, y2: int32): T =
  ## Finds all the values within a given rectangle
  when defined(logSearchSpace):
    var searchSpace = 0

  for scale in grid.eachScale:
    for key in eachCellIndex(x1, y1, x2, y2, scale):
      util.withValue(grid.cells, key, cell):
        for obj in cell:
          yield obj

      when defined(logSearchSpace):
        searchSpace += 1

  when defined(logSearchSpace):
    echo "Search space: ", searchSpace, " for rectangle ", (x1, y1), " to ", (x2, y2)

iterator find*[T](grid: AHGrid[T], x, y, radius: int32): T =
  ## Finds all the values that are approximately within a given radius of a point
  for elem in find(grid, x - radius, y - radius, x + radius, y + radius):
    yield elem

iterator items*[T](grid: AHGrid[T]): T =
  ## Iterates all values in this grid
  for cell in grid.cells.values:
    for obj in cell:
      yield obj

proc remove*[T](grid: AHGrid[T], handle: GridHandle[T]) =
  ## Removes a value
  tables.withValue(grid.cells, handle.key, cell):
    let index = cell[].find(handle.obj)
    if index >= 0:
      cell[].del(index)
      grid.scaleCounts[handle.key.scale.countTrailingZeroBits] -= 1

proc update*[T](handle: var GridHandle[T], space: SpatialObject) =
  ## Updates the spatial indexing for an object using the specified spatial information
  let newKey = space.pickCellIndex(handle.grid)
  if newKey != handle.key:
    handle.grid.remove(handle)
    insertAtKey(handle.grid, newKey, handle.obj)
    handle.key = newKey

proc update*[T: SpatialObject](handle: var GridHandle[T]) {.inline.} =
  ## Updates the spatial indexing for an object
  update(handle, handle.obj)

proc clear*[T](grid: AHGrid[T]) =
  ## Removes all values
  for cell in grid.cells.mvalues:
    cell.setLen(0)
  grid.scaleCounts = default(typeof(grid.scaleCounts))
  grid.maxScale = 0
