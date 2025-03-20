import benchy, std/[random, strformat], ahgrid

type Entry = tuple[x, y, width, height: int32]

proc makeEntries(num: int, posRange: Slice[int], sizeRange: Slice[int] = 1..1000): seq[Entry] =
  var rand = initRand(num.int64)
  for i in 0..<num:
    result.add (
      x: rand.rand(posRange).int32,
      y: rand.rand(posRange).int32,
      width: rand.rand(sizeRange).int32,
      height: rand.rand(sizeRange).int32
    )

for num in [10, 100, 1000]:
  for spread in [1_000, 10_000, 100_000, 1_000_000]:
    var entries = makeEntries(num, -spread..spread)
    for dist in [1'i32, 10, 100, 1_000]:
      timeIt fmt"{num} entries, spread over {spread} -- querying at {dist} distance", 100:
        var space = newAHGrid[Entry](dist * 10)
        for e in entries:
          space.insert(e)

        for me in entries:
          for other in space.find(me.x, me.y, dist):
            keep(other)
