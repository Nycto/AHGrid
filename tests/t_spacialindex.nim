import std/[unittest, math, sequtils], spacialindex

type
  GameObject = object
    name*: string
    x*, y*, width*, height*: int32

proc obj(name: string; x, y, width, height: int32): auto =
  GameObject(name: name, x: x, y: y, width: width, height: height)

suite "Hierarchical Spatial Hash Grid Tests":

  let rock = obj("Rock", x = 5, y = 5, width = 3, height = 3)
  let tree = obj("Tree", x = 20, y = 20, width = 15, height = 15)
  let bush = obj("Bush", x = 100, y = 100, width = 5, height = 5)

  test "Insertion and Query":
    var grid = newSpacialIndex[GameObject]()

    grid.insert(rock)
    grid.insert(tree)
    grid.insert(bush)

    check(grid.find(0, 0, 1).toSeq.len == 0)

    check(grid.find(5, 5, 1).toSeq.mapIt(it.name) == @[ "Rock" ])

    check(grid.find(6, 6, 2).toSeq.mapIt(it.name) == @[ "Rock" ])

    check(grid.find(15, 15, 10).toSeq.mapIt(it.name) == @[ "Rock", "Tree" ])

  test "Removal":
    var grid = newSpacialIndex[GameObject]()
    grid.insert(rock)

    check(grid.find(5, 5, 1).toSeq.len == 1)
    grid.remove(rock)
    check(grid.find(5, 5, 1).toSeq.len == 0)
    grid.remove(rock)
    check(grid.find(5, 5, 1).toSeq.len == 0)

  test "Clear":
    var grid = newSpacialIndex[GameObject]()
    grid.insert(rock)
    grid.insert(tree)
    grid.insert(bush)

    check(grid.find(50, 50, 50).toSeq.len == 3)

    grid.clear()
    check(grid.find(50, 50, 50).toSeq.len == 0)

  test "ToString":
    var grid = newSpacialIndex[GameObject]()

    check($grid == "SpacialIndex()")

    grid.insert(rock)
    grid.insert(tree)
    grid.insert(bush)

    check($grid == """SpacialIndex((x: 100, y: 100, scale: 8): @[(name: "Bush", x: 100, y: 100, width: 5, height: 5)], (x: 16, y: 16, scale: 32): @[(name: "Tree", x: 20, y: 20, width: 15, height: 15)], (x: 4, y: 4, scale: 8): @[(name: "Rock", x: 5, y: 5, width: 3, height: 3)], )""")