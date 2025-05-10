import std/[unittest, math, sequtils, algorithm]
import ahgrid {.all.}

type GameObject = ref object
  name*: string
  x*, y*, width*, height*: int32

proc `$`*(obj: GameObject): auto =
  $obj[]

proc obj(name: string, x, y, width, height: int32): auto =
  GameObject(name: name, x: x, y: y, width: width, height: height)

suite "Adaptive Hashing Grid":
  let rock = obj("Rock", x = 5, y = 5, width = 3, height = 3)
  let tree = obj("Tree", x = 20, y = 20, width = 15, height = 15)
  let bush = obj("Bush", x = 100, y = 100, width = 5, height = 5)
  let mountain = obj("Mountain", x = -200, y = -200, width = 500, height = 500)

  test "Insertion and Query within a radius":
    var grid = newAHGrid[GameObject]()

    discard grid.insert(rock)
    discard grid.insert(tree)
    discard grid.insert(bush)

    check(grid.find(0, 0, 1).toSeq.len == 0)

    check(grid.find(5, 5, 1).toSeq.mapIt(it.name) == @["Rock"])

    check(grid.find(6, 6, 2).toSeq.mapIt(it.name) == @["Rock"])

    check(grid.find(15, 15, 10).toSeq.mapIt(it.name) == @["Rock", "Tree"])

  test "Query within a rectangle":
    var grid = newAHGrid[GameObject]()

    discard grid.insert(rock)
    discard grid.insert(tree)
    discard grid.insert(bush)

    check(grid.find(0, 0, 1, 1).toSeq.len == 0)

    check(grid.find(3, 3, 7, 7).toSeq.mapIt(it.name) == @["Rock"])

  test "Iterating through all values":
    var grid = newAHGrid[GameObject]()
    check(grid.toSeq.len == 0)

    discard grid.insert(rock)
    discard grid.insert(tree)
    discard grid.insert(bush)
    discard grid.insert(mountain)

    check(grid.toSeq.mapIt(it.name).sorted == @["Bush", "Mountain", "Rock", "Tree"])

  test "Removal":
    var grid = newAHGrid[GameObject]()
    let handle = grid.insert(rock)

    check(grid.find(5, 5, 1).toSeq.len == 1)
    grid.remove(handle)
    check(grid.find(5, 5, 1).toSeq.len == 0)
    grid.remove(handle)
    check(grid.find(5, 5, 1).toSeq.len == 0)

  test "Updating the position of a value":
    var grid = newAHGrid[GameObject]()

    let fern = obj("fern", 1, 2, 3, 4)

    var handle = grid.insert(fern)
    check(grid.find(5, 5, 1).toSeq.len == 1)

    grid.update(handle)
    check(grid.find(5, 5, 1).toSeq.len == 1)
    check(grid.find(200, 5, 10).toSeq.len == 0)

    fern.x = 202
    grid.update(handle)
    check(grid.find(5, 5, 1).toSeq.len == 0)
    check(grid.find(200, 5, 10).toSeq.len == 1)

  test "Clear":
    var grid = newAHGrid[GameObject]()
    discard grid.insert(rock)
    discard grid.insert(tree)
    discard grid.insert(bush)

    check(grid.find(50, 50, 50).toSeq.len == 3)

    grid.clear()
    check(grid.find(50, 50, 50).toSeq.len == 0)

  test "ToString":
    var grid = newAHGrid[GameObject]()

    check($grid == "AHGrid()")

    discard grid.insert(rock)
    discard grid.insert(tree)
    discard grid.insert(bush)

    check(
      $grid ==
        """AHGrid(16x16x32: @[(name: "Tree", x: 20, y: 20, width: 15, height: 15)], 4x4x8: @[(name: "Rock", x: 5, y: 5, width: 3, height: 3)], 100x100x8: @[(name: "Bush", x: 100, y: 100, width: 5, height: 5)], )"""
    )

  test "Changing the minimum cell size":
    var grid = newAHGrid[GameObject](128)

    discard grid.insert(rock)
    discard grid.insert(tree)
    discard grid.insert(bush)
    discard grid.insert(mountain)

    check(grid.find(0, 0, 100).toSeq.len == 4)

  test "Normalized coordinates algorithm":
    var coordinates = [
      (x: 9, expectedAtScale2: 9, expectedAtScale4: 6, expectedAtScale8: 4),
      (x: 8, expectedAtScale2: 7, expectedAtScale4: 6, expectedAtScale8: 4),
      (x: 7, expectedAtScale2: 7, expectedAtScale4: 6, expectedAtScale8: 4),
      (x: 6, expectedAtScale2: 5, expectedAtScale4: 6, expectedAtScale8: 4),
      (x: 5, expectedAtScale2: 5, expectedAtScale4: 2, expectedAtScale8: 4),
      (x: 4, expectedAtScale2: 3, expectedAtScale4: 2, expectedAtScale8: 4),
      (x: 3, expectedAtScale2: 3, expectedAtScale4: 2, expectedAtScale8: -4),
      (x: 2, expectedAtScale2: 1, expectedAtScale4: 2, expectedAtScale8: -4),
      (x: 1, expectedAtScale2: 1, expectedAtScale4: -2, expectedAtScale8: -4),
      (x: 0, expectedAtScale2: -1, expectedAtScale4: -2, expectedAtScale8: -4),
      (x: -1, expectedAtScale2: -1, expectedAtScale4: -2, expectedAtScale8: -4),
      (x: -2, expectedAtScale2: -3, expectedAtScale4: -2, expectedAtScale8: -4),
      (x: -3, expectedAtScale2: -3, expectedAtScale4: -6, expectedAtScale8: -4),
      (x: -4, expectedAtScale2: -5, expectedAtScale4: -6, expectedAtScale8: -4),
      (x: -5, expectedAtScale2: -5, expectedAtScale4: -6, expectedAtScale8: -12),
      (x: -6, expectedAtScale2: -7, expectedAtScale4: -6, expectedAtScale8: -12),
      (x: -7, expectedAtScale2: -7, expectedAtScale4: -10, expectedAtScale8: -12),
      (x: -8, expectedAtScale2: -9, expectedAtScale4: -10, expectedAtScale8: -12),
      (x: -9, expectedAtScale2: -9, expectedAtScale4: -10, expectedAtScale8: -12),
    ]

    for (x, expectedAtScale2, expectedAtScale4, expectedAtScale8) in coordinates:
      checkpoint "x: " & $x
      check(chooseBucket(x.int32, 2) == expectedAtScale2.int32)
      check(chooseBucket(x.int32, 4) == expectedAtScale4.int32)
      check(chooseBucket(x.int32, 8) == expectedAtScale8.int32)

  test "Keys that fall on the very edge of a cell":
    var grid = newAHGrid[GameObject](minCellSize = 128)
    check(grid.pickCellIndex(81, 11, 78) == (-256'i32, -256'i32, 512'i32))

  test "Inserting values that don't have their own spatial info":
    var grid = newAHGrid[string]()

    var rockHandle = grid.insert("Rocks", rock)
    discard grid.insert("Trees", tree)
    discard grid.insert("Bushes", bush)

    check(grid.find(15, 15, 10).toSeq == @["Rocks", "Trees"])

    grid.update(rockHandle, bush)

    check(grid.find(15, 15, 10).toSeq == @["Trees"])
