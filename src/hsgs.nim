##
## Hierarchical Spatial Hash Grid
##

import std/[tables, sets]

type
  CellKey = tuple[x, y: int32]

  SpatialObject* = concept obj
    ## A value that can be stored in a 2d HSGS
    obj.x is int32
    obj.y is int32
    obj.width is int32
    obj.height is int32

  HSGS*[T: SpatialObject] = ref object
    ## A hierarchical spatial hash grid
    next: HSGS[T]
    cellSize: int32
    cells: Table[CellKey, seq[T]]

proc newLayer[T](cellSize: int32): auto =
  HSGS[T](cellSize: cellSize, cells: initTable[CellKey, seq[T]]())

proc newHSGS*[T](numLevels: SomeInteger, baseCellSize: int32): HSGS[T] =
  ## Create a new HSGS store
  result = newLayer[T](baseCellSize)
  var current = result
  for i in 1..<numLevels:
    current.next = newLayer[T](current.cellSize * 2)
    current = current.next

proc getCellIndex[T](grid: HSGS[T], x, y: int32): CellKey =
  (x div grid.cellSize, y div grid.cellSize)

iterator eachLayer[T](grid: HSGS[T], grow: bool = false): HSGS[T] =
  var layer = grid
  while layer != nil:
    yield layer
    if grow and layer.next == nil:
      layer.next = newLayer[T](layer.cellSize * 2)
    layer = layer.next

proc `$`*(grid: HSGS): string =
  result = "HSGS:\n"
  for layer in grid.eachLayer():
    result &= "  Level: " & $layer.cellSize & "\n"
    for key, cell in layer.cells.pairs:
      result &= "    Cell: " & $key & "\n"
      for obj in cell:
        result &= "     " & $obj & "\n"

iterator cellRange(minCell, maxCell: CellKey): CellKey =
  for x in minCell.x..maxCell.x:
    for y in minCell.x..maxCell.y:
      yield (x, y)

proc add*[T](grid: HSGS[T], obj: T) =
  ## Add a value to this spacial grid
  let size = max(obj.width, obj.height)

  for layer in grid.eachLayer(grow = true):
    if layer.cellSize >= size:
      let minCell = layer.getCellIndex(obj.x, obj.y)
      let maxCell = layer.getCellIndex(obj.x + obj.width, obj.y + obj.height)
      for cell in cellRange(minCell, maxCell):
        layer.cells.mgetOrPut(cell, @[]).add(obj)
      return

  raiseAssert("Could not find a layer to add to")

iterator find*[T](grid: HSGS[T]; x, y, radius: int32): T =
  ## Finds all the values within a given radius of a point
  var seen = initHashSet[T]()  # Track yielded objects
  for layer in grid.eachLayer():
    let minCell = layer.getCellIndex(x - radius, y - radius)
    let maxCell = layer.getCellIndex(x + radius, y + radius)
    for cell in cellRange(minCell, maxCell):
      if cell in layer.cells:
        for obj in layer.cells[cell]:
          if obj notin seen:
            seen.incl(obj)
            yield obj

# proc remove*[T, O](grid: HSGS[T, O], obj: O) =
#   ## Remove a value from this layer
#   for layer in grid.eachLayer():
#     let minCell = layer.getCellIndex(obj.x, obj.y)
#     let maxCell = layer.getCellIndex(obj.x + obj.width, obj.y + obj.height)
#     for cell in cellRange(minCell[0], minCell[1], maxCell[0], maxCell[1]):
#       if cell in layer.cells:
#         layer.cells[cell].keepItIf(proc(o: O): bool = o != obj)
# 
# proc clear[T, O](grid: HSGS[T, O]) =
#   for layer in grid.eachLayer():
#     layer.cells.clear()
