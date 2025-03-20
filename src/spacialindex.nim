##
## Spacial index that allows for querying of objects within a radius of a given point
##

import std/[tables, math, strformat]

type
  SpatialObject* = concept obj
    ## A value that can be stored in a 2d SpacialIndex
    obj.x is int32
    obj.y is int32
    obj.width is int32
    obj.height is int32

  CellKey = tuple[x, y, scale: int32]

  SpacialIndex*[T: SpatialObject] = object
    ## A 2d spacial index
    maxScale, minScale: int32
    cells: Table[CellKey, seq[T]]

proc newSpacialIndex*[T](minCellSize: int32 = 2): SpacialIndex[T] =
  ## Create a new SpacialIndex store
  result.cells = initTable[CellKey, seq[T]]()
  result.minScale = minCellSize.nextPowerOfTwo.int32

proc `$`*(grid: SpacialIndex): string =
  result = "SpacialIndex("
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

proc normalizeCoord(x, scale: int32): int32 =
  ## Normalizes a coordinate onto a line where the only valid values are multiples of `scale`.
  ## This also offsets each coordinate by `scale/2` to ensure that an entity that falls on the edge of
  ## its "best" cell won't fall into the edge on the next cell up
  assert(scale > 0, "Scale must be greater than 0")
  let half = scale div 2
  result = ((x + half) div scale * scale) - half

proc key(grid: SpacialIndex, x, y, dimen: int32): CellKey =
  ## Calculates the cell that a square falls into
  ## `x` and `y` are coordinates, `dimen` is the length of the side of the square

  let scale = max(dimen.int.nextPowerOfTwo.int32, grid.minScale)
  result = (x: x.normalizeCoord(scale), y: y.normalizeCoord(scale), scale: scale)

  # If the entity falls onto the edge between cells, put it in the next scale up
  if result.x + scale < x + dimen or result.y + scale < y + dimen:
    let scale = scale * 2
    result = (x: x.normalizeCoord(scale), y: y.normalizeCoord(scale), scale: scale)

  # The resulting cell should completely contain the object being stored
  assert(x >= result.x, fmt"{x} >= {result.x}")
  assert(y >= result.y, fmt"{y} >= {result.y}")
  assert(x + dimen <= result.x + result.scale, fmt"{x} + {dimen} <= {result.x} + {result.scale}")
  assert(y + dimen <= result.y + result.scale, fmt"{y} + {dimen} <= {result.y} + {result.scale}")

proc key(obj: SpatialObject, grid: SpacialIndex): CellKey =
  ## Calculates the cell that an object should be stored in
  key(grid, obj.x, obj.y, max(obj.height, obj.width))

proc insert*[T](grid: var SpacialIndex[T], obj: T) =
  ## Add a value to this spacial grid
  let key = obj.key(grid)
  grid.maxScale = max(grid.maxScale, key.scale)
  if grid.cells.hasKey(key):
    grid.cells[key].add(obj)
  else:
    grid.cells[key] = @[ obj ]

iterator eachScale(grid: SpacialIndex): int32 =
  ## Yields each scale present in the grid
  var scale = grid.minScale
  while scale <= grid.maxScale:
    yield scale
    scale *= 2

iterator eachCellKey(x, y, radius, scale: int32): CellKey =
  ## Yields each cell key within a given radius of a point at the given scale
  for x in normalizeCoord(x - radius, scale)..normalizeCoord(x + radius, scale):
    for y in normalizeCoord(y - radius, scale)..normalizeCoord(y + radius, scale):
      yield (x, y, scale)

iterator find*[T](grid: SpacialIndex[T]; x, y, radius: int32): T =
  ## Finds all the values within a given radius of a point
  for scale in grid.eachScale:
    for key in eachCellKey(x, y, radius, scale):
      if grid.cells.hasKey(key):
        for obj in grid.cells[key]:
          yield obj

proc remove*[T](grid: var SpacialIndex[T]; obj: T) =
  ## Removes a value
  let key = obj.key(grid)
  if grid.cells.hasKey(key):
    let index = grid.cells[key].find(obj)
    if index >= 0:
      grid.cells[key].del(index)

proc clear*[T](grid: var SpacialIndex[T]) =
  ## Removes all values
  grid.cells.clear()
  grid.maxScale = 0