##
## Spacial index that allows for querying of objects within a radius of a given point
##

import std/[tables, math, strformat]

type
  SpatialObject* = concept obj
    ## A value that can be stored in a 2d AHGrid
    obj.x is int32
    obj.y is int32
    obj.width is int32
    obj.height is int32

  CellKey = tuple[x, y, scale: int32]

  AHGrid*[T: SpatialObject] = object
    ## A 2d spacial index
    maxScale, minScale: int32
    cells: Table[CellKey, seq[T]]

proc newAHGrid*[T](minCellSize: int32 = 2): AHGrid[T] =
  ## Create a new AHGrid store
  result.cells = initTable[CellKey, seq[T]]()
  result.minScale = minCellSize.nextPowerOfTwo.int32

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

proc oneIfNegaitve(x: int32): int32 {.inline.} =
  ## Returns `1` if the value is positive, otherwise returns 0
  const shiftBy = sizeof(x).int32 * 8 - 1
  (x shr shiftBy) and 1

proc normalizeCoord(x, scale: int32): int32 =
  ## Normalizes a coordinate onto a line where the only valid values are multiples of `scale`.
  ## This also offsets each coordinate by `scale/2` to ensure that an entity that falls on the edge of
  ## its "best" cell won't fall into the edge on the next cell up
  assert(scale > 0, "Scale must be greater than 0")
  assert(scale.isPowerOfTwo, "Scale must be a power of two")

  let half = scale div 2

  let adjust = oneIfNegaitve(x + half) * (-scale + 1)
  # The above line is equivalent to:
  # let adjust = if x + half >= 0: 0'i32 else: -scale + 1

  result = (x + half + adjust) div scale * scale - half

proc buildCellKey(x, y, scale: int32): CellKey =
  (x: x.normalizeCoord(scale), y: y.normalizeCoord(scale), scale: scale)

proc key(grid: AHGrid, x, y, dimen: int32): CellKey =
  ## Calculates the cell that a square falls into
  ## `x` and `y` are coordinates, `dimen` is the length of the side of the square

  var scale = max(dimen.int.nextPowerOfTwo.int32, grid.minScale)
  result = buildCellKey(x, y, scale)

  # If the entity falls onto the edge between cells, put it in the next scale up
  while x + dimen >= result.x + scale or y + dimen >= result.y + scale:
    scale = scale * 2
    result = buildCellKey(x, y, scale)

  # The resulting cell should completely contain the object being stored
  assert(x >= result.x, fmt"{x} >= {result.x}")
  assert(y >= result.y, fmt"{y} >= {result.y}")
  assert(x + dimen <= result.x + result.scale, fmt"{x} + {dimen} <= {result.x} + {result.scale}")
  assert(y + dimen <= result.y + result.scale, fmt"{y} + {dimen} <= {result.y} + {result.scale}")

proc key(obj: SpatialObject, grid: AHGrid): CellKey =
  ## Calculates the cell that an object should be stored in
  key(grid, obj.x, obj.y, max(obj.height, obj.width))

proc insert*[T](grid: var AHGrid[T], obj: T) =
  ## Add a value to this spacial grid
  let key = obj.key(grid)
  grid.maxScale = max(grid.maxScale, key.scale)
  if grid.cells.hasKey(key):
    grid.cells[key].add(obj)
  else:
    grid.cells[key] = @[ obj ]

iterator eachScale(grid: AHGrid): int32 =
  ## Yields each scale present in the grid
  var scale = grid.minScale
  while scale <= grid.maxScale:
    yield scale
    scale *= 2

iterator eachCellKey(x, y, radius, scale: int32): CellKey =
  ## Yields each cell key within a given radius of a point at the given scale
  for x in countup(normalizeCoord(x - radius, scale), normalizeCoord(x + radius, scale), scale):
    for y in countup(normalizeCoord(y - radius, scale), normalizeCoord(y + radius, scale), scale):
      yield (x, y, scale)

iterator find*[T](grid: AHGrid[T]; x, y, radius: int32): T =
  ## Finds all the values within a given radius of a point
  when defined(logSearchSpace):
    var searchSpace = 0

  for scale in grid.eachScale:
    for key in eachCellKey(x, y, radius, scale):
      if grid.cells.hasKey(key):
        for obj in grid.cells[key]:
          yield obj

      when defined(logSearchSpace):
        searchSpace += 1

  when defined(logSearchSpace):
    echo "Search space: ", searchSpace, " at ", x, ", ", y, " with radius ", radius

proc remove*[T](grid: var AHGrid[T]; obj: T) =
  ## Removes a value
  let key = obj.key(grid)
  if grid.cells.hasKey(key):
    let index = grid.cells[key].find(obj)
    if index >= 0:
      grid.cells[key].del(index)

proc clear*[T](grid: var AHGrid[T]) =
  ## Removes all values
  for cell in grid.cells.mvalues:
    cell.setLen(0)
  grid.maxScale = 0