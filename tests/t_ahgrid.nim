import std/[unittest, math, sequtils]
import ahgrid {.all.}

type
  GameObject = object
    name*: string
    x*, y*, width*, height*: int32

proc obj(name: string; x, y, width, height: int32): auto =
  GameObject(name: name, x: x, y: y, width: width, height: height)

suite "Adaptive Hashing Grid":

  let rock = obj("Rock", x = 5, y = 5, width = 3, height = 3)
  let tree = obj("Tree", x = 20, y = 20, width = 15, height = 15)
  let bush = obj("Bush", x = 100, y = 100, width = 5, height = 5)
  let mountain = obj("mountain", x = -200, y = -200, width = 500, height = 500)

  test "Insertion and Query":
    var grid = newAHGrid[GameObject]()

    grid.insert(rock)
    grid.insert(tree)
    grid.insert(bush)

    check(grid.find(0, 0, 1).toSeq.len == 0)

    check(grid.find(5, 5, 1).toSeq.mapIt(it.name) == @[ "Rock" ])

    check(grid.find(6, 6, 2).toSeq.mapIt(it.name) == @[ "Rock" ])

    check(grid.find(15, 15, 10).toSeq.mapIt(it.name) == @[ "Rock", "Tree" ])

  test "Removal":
    var grid = newAHGrid[GameObject]()
    grid.insert(rock)

    check(grid.find(5, 5, 1).toSeq.len == 1)
    grid.remove(rock)
    check(grid.find(5, 5, 1).toSeq.len == 0)
    grid.remove(rock)
    check(grid.find(5, 5, 1).toSeq.len == 0)

  test "Clear":
    var grid = newAHGrid[GameObject]()
    grid.insert(rock)
    grid.insert(tree)
    grid.insert(bush)

    check(grid.find(50, 50, 50).toSeq.len == 3)

    grid.clear()
    check(grid.find(50, 50, 50).toSeq.len == 0)

  test "ToString":
    var grid = newAHGrid[GameObject]()

    check($grid == "AHGrid()")

    grid.insert(rock)
    grid.insert(tree)
    grid.insert(bush)

    check($grid == """AHGrid((x: 100, y: 100, scale: 8): @[(name: "Bush", x: 100, y: 100, width: 5, height: 5)], (x: 16, y: 16, scale: 32): @[(name: "Tree", x: 20, y: 20, width: 15, height: 15)], (x: 4, y: 4, scale: 8): @[(name: "Rock", x: 5, y: 5, width: 3, height: 3)], )""")

  test "Changing the minimum cell size":
    var grid = newAHGrid[GameObject](128)

    grid.insert(rock)
    grid.insert(tree)
    grid.insert(bush)
    grid.insert(mountain)

    check(grid.find(0, 0, 100).toSeq.len == 4)

  test "Normalized coordinates algorithm":
    var coordinates = [
      (x:  9, expectedAtScale2:  9, expectedAtScale4:   6, expectedAtScale8:    4),
      (x:  8, expectedAtScale2:  7, expectedAtScale4:   6, expectedAtScale8:    4),
      (x:  7, expectedAtScale2:  7, expectedAtScale4:   6, expectedAtScale8:    4),
      (x:  6, expectedAtScale2:  5, expectedAtScale4:   6, expectedAtScale8:    4),
      (x:  5, expectedAtScale2:  5, expectedAtScale4:   2, expectedAtScale8:    4),
      (x:  4, expectedAtScale2:  3, expectedAtScale4:   2, expectedAtScale8:    4),
      (x:  3, expectedAtScale2:  3, expectedAtScale4:   2, expectedAtScale8:   -4),
      (x:  2, expectedAtScale2:  1, expectedAtScale4:   2, expectedAtScale8:   -4),
      (x:  1, expectedAtScale2:  1, expectedAtScale4:  -2, expectedAtScale8:   -4),
      (x:  0, expectedAtScale2: -1, expectedAtScale4:  -2, expectedAtScale8:   -4),
      (x: -1, expectedAtScale2: -1, expectedAtScale4:  -2, expectedAtScale8:   -4),
      (x: -2, expectedAtScale2: -3, expectedAtScale4:  -2, expectedAtScale8:   -4),
      (x: -3, expectedAtScale2: -3, expectedAtScale4:  -6, expectedAtScale8:   -4),
      (x: -4, expectedAtScale2: -5, expectedAtScale4:  -6, expectedAtScale8:   -4),
      (x: -5, expectedAtScale2: -5, expectedAtScale4:  -6, expectedAtScale8:  -12),
      (x: -6, expectedAtScale2: -7, expectedAtScale4:  -6, expectedAtScale8:  -12),
      (x: -7, expectedAtScale2: -7, expectedAtScale4: -10, expectedAtScale8:  -12),
      (x: -8, expectedAtScale2: -9, expectedAtScale4: -10, expectedAtScale8:  -12),
      (x: -9, expectedAtScale2: -9, expectedAtScale4: -10, expectedAtScale8:  -12),
    ]

    for (x, expectedAtScale2, expectedAtScale4, expectedAtScale8) in coordinates:
      checkpoint "x: " & $x
      check(normalizeCoord(x.int32, 2) == expectedAtScale2.int32)
      check(normalizeCoord(x.int32, 4) == expectedAtScale4.int32)
      check(normalizeCoord(x.int32, 8) == expectedAtScale8.int32)

  test "Keys that fall on the very edge of a cell":
    var grid = newAHGrid[GameObject](128)
    check(grid.key(81, 11, 78) == (-256'i32, -256'i32, 512'i32))