##
## Spacial index that allows for querying of objects within a radius of a given point
##
## Details about the specific sof this algorithm can be found here:
##
## https://elephantstarballoon.com/post/ahgrid/
##
runnableExamples:
  var grid = newAHGrid[tuple[x, y, width, height: int32]]()

  discard grid.insert((x: 1'i32, y: 2'i32, width: 3'i32, height: 4'i32))
  discard grid.insert((x: 5'i32, y: 6'i32, width: 7'i32, height: 8'i32))

  for obj in grid.find(3, 4, 10):
    echo "Found object near point: ", obj

import std/[tables, math, strformat, hashes], private/util

type
  SpatialObject* =
    concept obj
        ## A value that can be stored in a 2d AHGrid
        obj.x is int32
        obj.y is int32
        obj.width is int32
        obj.height is int32

  GridHandle*[T] = object
    ## A handle for a value that can be stored in a AHGrid -- used to update that value
    obj: T
    key: CellIndex
    grid: ptr AHGrid[T]

  CellIndex = tuple[xBucket, yBucket, scale: int32]

  AHGrid*[T] {.requiresInit.} = object ## A 2d spacial index
    maxScale, minScale: int32
    cells: Table[CellIndex, seq[T]]

proc `=copy`[T](a: var GridHandle[T], b: GridHandle[T]) {.error.}

proc remove*[T](grid: var AHGrid[T], handle: GridHandle[T])

proc `=destroy`[T](handle: var GridHandle[T]) =
  if handle.grid != nil:
    handle.grid[].remove(handle)

proc hash*(x: CellIndex): Hash =
  return x.yBucket !& x.xBucket !& x.scale

proc newAHGrid*[T](
    initialSize: Positive = defaultInitialSize, minCellSize: int32 = 2
): AHGrid[T] =
  ## Create a new AHGrid store
  return AHGrid[T](
    minScale: minCellSize.nextPowerOfTwo.int32,
    maxScale: 0,
    cells: initTable[CellIndex, seq[T]](initialSize),
  )

proc `=copy`*[T](a: var AHGrid[T], b: AHGrid[T]) {.error.}

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
  ## its "best" cell won't fall into the edge on the net cell up
  assert(scale > 0, "Scale must be greater than 0")
  assert(scale.isPowerOfTwo, "Scale must be a power of two")

  let half = scale div 2

  # We need to specifically adjust the index to handle negative coordinates
  let adjust =
    if coord + half >= 0:
      0'i32
    else:
      -scale + 1

  result = (coord + half + adjust) div scale * scale - half

proc pickCellIndex(grid: AHGrid, x, y, dimen: int32): CellIndex =
  ## Calculates the cell that a square falls into
  ## `x` and `y` are coordinates, `dimen` is the length of the side of the square

  var scale = max(dimen.int.nextPowerOfTwo.int32, grid.minScale)

  while true:
    result =
      (xBucket: x.chooseBucket(scale), yBucket: y.chooseBucket(scale), scale: scale)

    # If the entity fits completely into the cell we've picked, we're done.
    if x + dimen < result.xBucket + scale and y + dimen < result.yBucket + scale:
      break

    # If it doesn't fit, we need to try the next scale up
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

proc insertAtKey[T](grid: var AHGrid[T], key: CellIndex, obj: T) =
  ## Inserts a value when the key is already known
  grid.maxScale = max(grid.maxScale, key.scale)
  grid.cells.mgetOrPut(key, newSeq[T]()).add(obj)

proc insert*[T](grid: var AHGrid[T], value: T, space: SpatialObject): GridHandle[T] =
  ## Add a value to this spacial grid
  let key = space.pickCellIndex(grid)
  insertAtKey(grid, key, value)
  return GridHandle[T](key: key, obj: value, grid: addr grid)

proc insert*[T: SpatialObject](
    grid: var AHGrid[T], value: T
): GridHandle[T] {.inline.} =
  ## Add a value to this spacial grid
  insert(grid, value, value)

iterator eachScale(grid: AHGrid): int32 =
  ## Yields each scale present in the grid
  var scale = grid.minScale
  while scale <= grid.maxScale:
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
      withValue(grid.cells, key, cell):
        for obj in cell:
          yield obj

      when defined(logSearchSpace):
        searchSpace += 1

  when defined(logSearchSpace):
    echo "Search space: ", searchSpace, " at ", x, ", ", y, " with radius ", radius

iterator find*[T](grid: AHGrid[T], x, y, radius: int32): T =
  ## Finds all the values that are approximately within a given radius of a point
  for elem in find(grid, x - radius, y - radius, x + radius, y + radius):
    yield elem

iterator items*[T](grid: AHGrid[T]): T =
  ## Iterates all values in this grid
  for cell in grid.cells.values:
    for obj in cell:
      yield obj

proc remove*[T](grid: var AHGrid[T], handle: GridHandle[T]) =
  ## Removes a value
  try:
    let index = grid.cells[handle.key].find(handle.obj)
    if index >= 0:
      grid.cells[handle.key].del(index)
  except KeyError:
    discard

proc update*[T](grid: var AHGrid[T], handle: var GridHandle[T], space: SpatialObject) =
  ## Updates the spatial indexing for an object using the specified spatial information
  let newKey = space.pickCellIndex(grid)
  if newKey != handle.key:
    grid.remove(handle)
    insertAtKey(grid, newKey, handle.obj)
    handle.key = newKey

proc update*[T: SpatialObject](
    grid: var AHGrid[T], handle: var GridHandle[T]
) {.inline.} =
  ## Updates the spatial indexing for an object
  update(grid, handle, handle.obj)

proc clear*[T](grid: var AHGrid[T]) =
  ## Removes all values
  for cell in grid.cells.mvalues:
    cell.setLen(0)
  grid.maxScale = 0
