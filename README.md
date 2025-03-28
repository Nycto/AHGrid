# AHGrid: A spatial indexing library

[![Build](https://github.com/Nycto/AHGrid/actions/workflows/build.yml/badge.svg)](https://github.com/Nycto/AHGrid/actions/workflows/build.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-purple.svg)](https://github.com/NecsusECS/Necsus/blob/main/LICENSE)
[![API Documentation](https://img.shields.io/badge/nim-documentation-blue)](https://nycto.github.io/AHGrid/)

AHGrid is a library for indexing, updating, and querying objects on a grid. To
learn more about the underlying approach, see the detailed explanation
[here](https://elephantstarballoon.com/post/ahgrid/).

## Installation

To install AHGrid using Nimble, run:

```sh
nimble install https://github.com/Nycto/AHGrid.git
```

## Usage

Refer to the [API Documentation](https://nycto.github.io/AHGrid/) for detailed usage examples and function references.

### Example

```nim
import ahgrid

var grid = newAHGrid[tuple[x, y, width, height: int32]]()

discard grid.insert((x: 1'i32, y: 2'i32, width: 3'i32, height: 4'i32))
discard grid.insert((x: 5'i32, y: 6'i32, width: 7'i32, height: 8'i32))

for obj in grid.find(3, 4, 10):
echo "Found object near point: ", obj
```

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

