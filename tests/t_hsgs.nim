import std/[unittest, math, sequtils], hsgs

type
  GameObject = object
    name*: string
    x*, y*, width*, height*: int32

proc obj(name: string; x, y, width, height: int32): auto =
  GameObject(name: name, x: x, y: y, width: width, height: height)

suite "Hierarchical Spatial Hash Grid Tests":

  let rock = obj("Rock", x = 5, y = 5, width = 3, height = 3)
  let tree = obj("Tree", x = 20, y = 20, width = 15, height = 15)

  test "Insertion and Query":
    var grid = newHSGS[GameObject]()

    grid.add(rock)
    grid.add(tree)

    echo $grid

    check(grid.find(5, 5, 2).toSeq.mapIt(it.name) == @[ "Rock" ])

    # check found, "Rock should be found within query range"

#   test "Removal":
#     let bush = GameObject(name: "Bush", pos: (10.0, 10.0), size: (2.0, 2.0))
#     grid.insert(bush)
# 
#     check len(toSeq(grid.query((10.0, 10.0), radius = 5.0))) == 1
#     grid.remove(bush)
#     check len(toSeq(grid.query((10.0, 10.0), radius = 5.0))) == 0, "Bush should be removed"
# 
#   test "Clear":
#     let rock = GameObject(name: "Rock", pos: (5.0, 5.0), size: (3.0, 3.0))
#     let tree = GameObject(name: "Tree", pos: (20.0, 20.0), size: (15.0, 15.0))
#     grid.insert(rock)
#     grid.insert(tree)
# 
#     grid.clear()
#     check len(toSeq(grid.query((0.0, 0.0), radius = 50.0))) == 0, "Grid should be empty after clear"
# 
#   test "Query Multiple Levels":
#     let largeObject = GameObject(name: "LargeObject", pos: (30.0, 30.0), size: (20.0, 20.0))
#     let smallObject = GameObject(name: "SmallObject", pos: (32.0, 32.0), size: (4.0, 4.0))
# 
#     grid.insert(largeObject)
#     grid.insert(smallObject)
# 
#     var foundLarge = false
#     var foundSmall = false
#     for obj in grid.query((30.0, 30.0), radius = 5.0):
#       if obj.name == "LargeObject": foundLarge = true
#       if obj.name == "SmallObject": foundSmall = true
# 
#     check foundLarge, "Large object should be found in coarse level"
#     check foundSmall, "Small object should be found in fine level"
# 
#   test "Iterator for Linked Levels":
#     var count = 0
#     for _ in grid.traverseNodes():
#       inc count
#     check count == 3, "There should be 3 levels in the linked list"
# 
#   test "Cell Range Iterator":
#     let obj1 = GameObject(name: "Obj1", pos: (10.0, 10.0), size: (2.0, 2.0))
#     let obj2 = GameObject(name: "Obj2", pos: (15.0, 15.0), size: (2.0, 2.0))
#     
#     grid.insert(obj1)
#     grid.insert(obj2)
# 
#     var count = 0
#     for cell in cellRange((1,1), (2,2)): # Assuming cellSize = 10.0
#       count += 1
# 
#     check count > 0, "Cell range iterator should yield at least one value"